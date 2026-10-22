import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:scentle_app/core/theme/scentle_theme.dart';
import 'package:scentle_app/models/multiplayer_room.dart';
import 'package:scentle_app/providers/game_provider.dart';
import 'package:scentle_app/providers/multiplayer_provider.dart';
import 'package:scentle_app/services/ad_service.dart';
import 'package:scentle_app/services/game_engine_service.dart';
import 'package:scentle_app/services/multiplayer_transport.dart';
import 'package:scentle_app/services/network_time_service.dart';
import 'package:scentle_app/services/perfume_repository.dart';
import 'package:scentle_app/services/smart_bot_controller.dart';
import 'package:scentle_app/services/storage_service.dart';
import 'package:scentle_app/widgets/settings_modal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PerfumeRepository repository;
  late StorageService storage;
  late GameEngineService engine;

  setUpAll(() async {
    // Disable runtime HTTP font fetching in test environment to avoid network timeouts
    GoogleFonts.config.allowRuntimeFetching = false;

    repository = PerfumeRepository.instance;
    await repository.initialize();

    storage = StorageService.instance;
    await storage.initialize();

    engine = const GameEngineService();
  });

  tearDown(() async {
    await storage.clearAllBoxesForTesting();
    NetworkTimeService.instance.resetForTesting();
  });

  group('Batch 6: SmartBotController AI Opponent Heuristics', () {
    test('1. Enthusiast Handle Pool contains 40 unique non-empty fragrance names', () {
      final names = SmartBotController.enthusiastNicknames;
      expect(names.length, 40);
      expect(names.toSet().length, 40, reason: 'All 40 handles must be unique');
      for (final name in names) {
        expect(name.trim().isNotEmpty, isTrue);
      }
    });

    test('2. Bot ELO calibration generates rating within ±120 points and clamped', () {
      const playerElo = 1200;
      for (int i = 0; i < 50; i++) {
        final bot = SmartBotController.create(
          playerElo: playerElo,
          repository: repository,
          engine: engine,
          transport: LocalLoopbackTransport.isolated(),
        );

        expect(bot.elo, greaterThanOrEqualTo(800));
        expect(bot.elo, lessThanOrEqualTo(2400));
        expect((bot.elo - playerElo).abs(), lessThanOrEqualTo(120));
        expect(bot.botId.startsWith('bot_'), isTrue);
        expect(bot.nickname.isNotEmpty, isTrue);
      }
    });

    test('3. Progressive deduction heuristics produce valid authentic guesses across turns 1-6', () {
      final target = repository.mysteryPool.first;
      final bot = SmartBotController.create(
        playerElo: 1200,
        repository: repository,
        engine: engine,
        transport: LocalLoopbackTransport.isolated(),
      );

      final previousIds = <int>{};

      for (int turn = 1; turn <= 6; turn++) {
        final guess = bot.selectGuess(
          turn: turn,
          target: target,
          previousGuessIds: previousIds,
        );

        expect(guess, isNotNull);
        expect(guess.name.isNotEmpty, isTrue);
        expect(guess.brand.isNotEmpty, isTrue);

        final evalResult = engine.evaluateGuess(guess, target);
        expect(evalResult.multiplayerColorRow.length, 4);
        for (final color in evalResult.multiplayerColorRow) {
          expect(['EXACT', 'CLOSE', 'MISS'].contains(color), isTrue);
        }

        if (guess.id != target.id) {
          previousIds.add(guess.id);
        }
      }
    });

    test('4. Bot turn loop updates room state, computes closeness, and finishes on solve', () async {
      final transport = LocalLoopbackTransport.isolated();
      final target = repository.mysteryPool.first;

      final bot = SmartBotController.create(
        playerElo: 1100,
        repository: repository,
        engine: engine,
        transport: transport,
        customStepDelay: const Duration(milliseconds: 15),
      );

      final hostState = MultiplayerPlayerState(
        playerId: 'player_human',
        nickname: 'Human Player',
        elo: 1100,
        lastActionEpochMs: DateTime.now().millisecondsSinceEpoch,
      );

      final botState = MultiplayerPlayerState(
        playerId: bot.botId,
        nickname: bot.nickname,
        elo: bot.elo,
        lastActionEpochMs: DateTime.now().millisecondsSinceEpoch,
        isBot: true,
      );

      const roomCode = 'BOT1';
      final room = MultiplayerRoom(
        roomCode: roomCode,
        isPublic: false,
        status: 'playing',
        targetPerfumeId: target.id,
        createdAtEpochMs: DateTime.now().millisecondsSinceEpoch,
        players: {
          'player_human': hostState,
          bot.botId: botState,
        },
      );

      await transport.createOrUpdateRoom(room);

      // Run bot turns with rapid delay
      await bot.runBotTurnLoop(
        roomCode: roomCode,
        target: target,
      );

      final updatedRoom = await transport.fetchRoom(roomCode);
      expect(updatedRoom, isNotNull);

      final finalBotState = updatedRoom!.players[bot.botId];
      expect(finalBotState, isNotNull);
      expect(finalBotState!.turnCount, greaterThan(0));
      expect(finalBotState.colorGrid.isNotEmpty, isTrue);
      expect(bot.botGuesses.isNotEmpty, isTrue);
    });
  });

  group('Batch 6: Public Quick Matchmaking & 6-Second Auto-Bot Fallback', () {
    test('1. startQuickMatch joins existing open public room immediately as Player 2', () async {
      final transport = LocalLoopbackTransport.isolated();
      final target = repository.mysteryPool.first;

      // Host creates open public room
      final hostState = MultiplayerPlayerState(
        playerId: 'host_player',
        nickname: 'Host Nose',
        elo: 1050,
        lastActionEpochMs: DateTime.now().millisecondsSinceEpoch,
      );

      const openCode = 'PUB1';
      final publicRoom = MultiplayerRoom(
        roomCode: openCode,
        isPublic: true,
        status: 'waiting',
        targetPerfumeId: target.id,
        createdAtEpochMs: DateTime.now().millisecondsSinceEpoch,
        players: {'host_player': hostState},
      );

      await transport.createOrUpdateRoom(publicRoom);

      // Challenger starts quick match
      final challengerProvider = MultiplayerProvider(
        playerId: 'challenger_player',
        transport: transport,
        repository: repository,
        storage: storage,
      );

      await challengerProvider.startQuickMatch(
        queueTimeout: const Duration(seconds: 6),
      );

      expect(challengerProvider.currentRoom, isNotNull);
      expect(challengerProvider.currentRoom!.roomCode, openCode);
      expect(challengerProvider.currentRoom!.status, 'playing');
      expect(challengerProvider.isMatchmaking, isFalse);

      await challengerProvider.leaveRoom();
    });

    test('2. startQuickMatch times out and seamlessly spawns SmartBotController as Player 2', () async {
      final transport = LocalLoopbackTransport.isolated();

      final playerProvider = MultiplayerProvider(
        playerId: 'solo_queuer',
        transport: transport,
        repository: repository,
        storage: storage,
      );

      // Queue with 50ms rapid timeout for deterministic testing
      await playerProvider.startQuickMatch(
        queueTimeout: const Duration(milliseconds: 50),
        botTurnDelay: const Duration(seconds: 1),
      );

      // Initial state: room created, waiting in matchmaking queue
      expect(playerProvider.currentRoom, isNotNull);
      expect(playerProvider.currentRoom!.isPublic, isTrue);

      // Allow 50ms queue timer to fire
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Room should transition to playing with SmartBotController
      expect(playerProvider.isMatchmaking, isFalse);
      expect(playerProvider.currentRoom!.status, 'playing');
      expect(playerProvider.currentRoom!.players.length, 2);

      final botPlayer = playerProvider.opponentState;
      expect(botPlayer, isNotNull);
      expect(botPlayer!.isBot, isTrue);
      expect(botPlayer.playerId.startsWith('bot_'), isTrue);

      await playerProvider.leaveRoom();
    });

    test('3. cancelQuickMatch gracefully leaves queue and deletes waiting room', () async {
      final transport = LocalLoopbackTransport.isolated();

      final playerProvider = MultiplayerProvider(
        playerId: 'canceller_player',
        transport: transport,
        repository: repository,
        storage: storage,
      );

      await playerProvider.startQuickMatch(
        queueTimeout: const Duration(seconds: 10),
      );

      expect(playerProvider.isMatchmaking, isTrue);
      final roomCode = playerProvider.currentRoom!.roomCode;

      await playerProvider.cancelQuickMatch();

      expect(playerProvider.isMatchmaking, isFalse);
      expect(playerProvider.currentRoom, isNull);

      final fetched = await transport.fetchRoom(roomCode);
      expect(fetched, isNull, reason: 'Waiting solitary room should be cleaned up on cancel');
    });
  });

  group('Batch 6: NetworkTimeService UTC Verification & Anti-Time-Travel', () {
    test('1. HttpDate parsing correctly extracts UTC time from standard HTTP date header', () async {
      final mockClient = MockClient((request) async {
        return http.Response('', 200, headers: {
          'date': 'Sun, 18 Oct 2026 12:00:00 GMT',
        });
      });

      final service = NetworkTimeService.instance;
      final verifiedTime = await service.syncNetworkTime(client: mockClient);

      expect(service.isVerifiedNetworkTime, isTrue);
      expect(verifiedTime.year, 2026);
      expect(verifiedTime.month, 10);
      expect(verifiedTime.day, 18);
      expect(verifiedTime.hour, 12);
    });

    test('2. Flags device clock manipulation if phone is altered by >= 2 hours', () async {
      final service = NetworkTimeService.instance;

      // Simulate a 4-hour forward device clock
      service.setOffsetForTesting(const Duration(hours: -4));
      expect(service.isTimeManipulated, isTrue);

      // Simulate an accurate device clock (within 10 seconds)
      service.setOffsetForTesting(const Duration(seconds: 5));
      expect(service.isTimeManipulated, isFalse);
    });

    test('3. Graceful offline fallback returns device UTC without throwing', () async {
      final failingClient = MockClient((request) async {
        throw const SocketException('Network is unreachable');
      });

      final service = NetworkTimeService.instance;
      final fallbackDate = await service.syncNetworkTime(client: failingClient);

      expect(service.isVerifiedNetworkTime, isFalse);
      expect(fallbackDate, isNotNull);
      expect(service.getVerifiedUtcDate(), isNotNull);
    });

    test('4. GameProvider uses NetworkTimeService for daily puzzle date', () async {
      final service = NetworkTimeService.instance;
      // Set network date to a specific reference date in 2026
      service.setOffsetForTesting(
        DateTime.utc(2026, 11, 20).difference(DateTime.now().toUtc()),
      );

      final gameProvider = GameProvider(
        repository: repository,
        storage: storage,
      );

      await gameProvider.startDailyGame();
      expect(gameProvider.activeDateStr, '2026-11-20');
    });
  });

  group('Batch 6: AdService Rewarded Atelier Hint Stub', () {
    test('1. Immediate grant when duration is Duration.zero', () async {
      final mockContext = _MockBuildContext();
      final granted = await AdService.showRewardedHintAd(
        mockContext,
        duration: Duration.zero,
      );
      expect(granted, isTrue);
    });

    testWidgets('2. Ad dialog renders countdown and completes impression', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ScentleTheme.darkTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => AdService.showRewardedHintAd(
                  context,
                  duration: const Duration(milliseconds: 100),
                ),
                child: const Text('OPEN AD'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('OPEN AD'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('ATELIER SPONSOR PREVIEW'), findsOneWidget);
      expect(find.text('HAUTE PARFUMERIE ARCHIVE'), findsOneWidget);

      // Advance through duration to completion
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.text('CLAIM SECRET NOTE'), findsOneWidget);

      await tester.tap(find.text('CLAIM SECRET NOTE'));
      await tester.pumpAndSettle();
      expect(find.text('ATELIER SPONSOR PREVIEW'), findsNothing);
    });
  });

  group('Batch 6: StorageService Preferences & SettingsModal', () {
    test('1. Preference getters and setters persist in settingsBox', () async {
      expect(storage.isFirstLaunch(), isTrue);
      await storage.setFirstLaunchCompleted();
      expect(storage.isFirstLaunch(), isFalse);

      expect(storage.isHapticEnabled(), isTrue);
      await storage.setHapticEnabled(false);
      expect(storage.isHapticEnabled(), isFalse);

      expect(storage.isSoundEnabled(), isTrue);
      await storage.setSoundEnabled(false);
      expect(storage.isSoundEnabled(), isFalse);
    });

    testWidgets('2. SettingsModal renders identity, toggles, and fair-use disclaimer', (tester) async {
      final multiplayerProvider = MultiplayerProvider(
        repository: repository,
        storage: storage,
        transport: LocalLoopbackTransport.isolated(),
      );
      addTearDown(() => multiplayerProvider.dispose());

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<MultiplayerProvider>.value(value: multiplayerProvider),
          ],
          child: MaterialApp(
            theme: ScentleTheme.darkTheme,
            home: const Scaffold(
              body: SettingsModal(),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('ATELIER SETTINGS'), findsOneWidget);
      expect(find.text('OLFACTORY IDENTITY'), findsOneWidget);
      expect(find.text('Haptic Feedback'), findsOneWidget);
      expect(find.text('Sound Effects'), findsOneWidget);
      expect(find.text('HOW TO PLAY & FORMULATION RULES'), findsOneWidget);
      expect(find.text('TRADEMARK & COPYRIGHT NOTICE'), findsOneWidget);
      expect(find.textContaining('Nominative Fair Use'), findsOneWidget);
      expect(find.textContaining('Fragrantica'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}

class _MockBuildContext extends Fake implements BuildContext {}
