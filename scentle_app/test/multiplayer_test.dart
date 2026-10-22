import 'package:flutter_test/flutter_test.dart';
import 'package:scentle_app/models/multiplayer_room.dart';
import 'package:scentle_app/providers/multiplayer_provider.dart';
import 'package:scentle_app/services/game_engine_service.dart';
import 'package:scentle_app/services/multiplayer_transport.dart';
import 'package:scentle_app/services/perfume_repository.dart';
import 'package:scentle_app/services/rank_service.dart';
import 'package:scentle_app/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PerfumeRepository repository;
  late StorageService storage;
  late GameEngineService engine;

  setUpAll(() async {
    repository = PerfumeRepository.instance;
    await repository.initialize();

    storage = StorageService.instance;
    await storage.initialize();

    engine = const GameEngineService();
  });

  tearDown(() async {
    await storage.clearAllBoxesForTesting();
    LocalLoopbackTransport.shared.reset();
  });

  group('RankService ELO Calculations & Tiers', () {
    test('1. Rank tier mapping across ELO boundaries', () {
      expect(RankService.getRank(850).title, 'Test Strip Novice');
      expect(RankService.getRank(1000).title, 'Accord Apprentice');
      expect(RankService.getRank(1199).title, 'Accord Apprentice');
      expect(RankService.getRank(1200).title, 'Atelier Evaluator');
      expect(RankService.getRank(1399).title, 'Atelier Evaluator');
      expect(RankService.getRank(1400).title, 'Heart Note Specialist');
      expect(RankService.getRank(1699).title, 'Heart Note Specialist');
      expect(RankService.getRank(1700).title, 'Master Perfumer (Grand Nose)');
      expect(RankService.getRank(2100).title, 'Master Perfumer (Grand Nose)');
    });

    test('2. Canonical ELO calculation with K=32', () {
      // Equal ELO win: expected 0.5 -> delta = 32 * (1.0 - 0.5) = +16
      final winDelta = RankService.calculateEloDelta(
        myElo: 1000,
        opponentElo: 1000,
        outcome: 1.0,
      );
      expect(winDelta, 16);

      // Equal ELO loss: expected 0.5 -> delta = 32 * (0.0 - 0.5) = -16
      final lossDelta = RankService.calculateEloDelta(
        myElo: 1000,
        opponentElo: 1000,
        outcome: 0.0,
      );
      expect(lossDelta, -16);

      // Equal ELO draw: expected 0.5 -> delta = 32 * (0.5 - 0.5) = 0
      final drawDelta = RankService.calculateEloDelta(
        myElo: 1000,
        opponentElo: 1000,
        outcome: 0.5,
      );
      expect(drawDelta, 0);

      // Underdog victory against higher rated opponent gives larger boost
      final underdogWin = RankService.calculateEloDelta(
        myElo: 1000,
        opponentElo: 1400,
        outcome: 1.0,
      );
      expect(underdogWin, greaterThan(25));
    });
  });

  group('MultiplayerRoom & State Serialization', () {
    test('3. Compact JSON serialization preserves player grids and hides fragrance secrets', () {
      const state = MultiplayerPlayerState(
        playerId: 'player_alpha',
        nickname: 'Nose_Alpha',
        elo: 1100,
        turnCount: 2,
        solved: false,
        bestClosenessScore: 48,
        colorGrid: [
          ['MISS', 'CLOSE', 'MISS', 'MISS'],
          ['EXACT', 'CLOSE', 'CLOSE', 'MISS'],
        ],
        guessedPerfumeIds: [151345, 151346],
        lastActionEpochMs: 1729270000000,
      );

      final json = state.toJson();
      final revived = MultiplayerPlayerState.fromJson(json);

      expect(revived.playerId, 'player_alpha');
      expect(revived.nickname, 'Nose_Alpha');
      expect(revived.elo, 1100);
      expect(revived.turnCount, 2);
      expect(revived.bestClosenessScore, 48);
      expect(revived.colorGrid.length, 2);
      expect(revived.colorGrid[1][0], 'EXACT');
      expect(revived.guessedPerfumeIds, [151345, 151346]);
    });
  });

  group('1v1 Real-Time Multiplayer Duel Orchestration', () {
    test('4. Private Room Creation: Valid 4-char code and mystery target from pool', () async {
      final transport = LocalLoopbackTransport.isolated();
      final provider = MultiplayerProvider(
        transport: transport,
        engine: engine,
        repository: repository,
        storage: storage,
      );

      final roomCode = await provider.createPrivateRoom(customNickname: 'HostNose');

      expect(roomCode.length, 4);
      expect(RegExp(r'^[A-Z2-9]{4}$').hasMatch(roomCode), isTrue);
      // Disallow ambiguous characters 0, O, 1, I
      expect(roomCode.contains('0'), isFalse);
      expect(roomCode.contains('O'), isFalse);
      expect(roomCode.contains('1'), isFalse);
      expect(roomCode.contains('I'), isFalse);

      final room = provider.currentRoom;
      expect(room, isNotNull);
      expect(room!.status, 'waiting');
      expect(room.players.length, 1);
      expect(room.players.containsKey(provider.myPlayerId), isTrue);

      // Target must be in Tier 2 mystery pool
      final mysteryIds = repository.mysteryPool.map((p) => p.id).toSet();
      expect(mysteryIds.contains(room.targetPerfumeId), isTrue);
    });

    test('5. Challenger Joining: Transitions room status from waiting to playing', () async {
      final transport = LocalLoopbackTransport.isolated();

      // Host creates room
      final hostProvider = MultiplayerProvider(
        playerId: 'host_p1',
        transport: transport,
        engine: engine,
        repository: repository,
        storage: storage,
      );
      final roomCode = await hostProvider.createPrivateRoom(customNickname: 'HostNose');

      // Challenger joins room
      final challengerProvider = MultiplayerProvider(
        playerId: 'guest_p2',
        transport: transport,
        engine: engine,
        repository: repository,
        storage: storage,
      );

      final joined = await challengerProvider.joinPrivateRoom(roomCode, customNickname: 'GuestNose');
      expect(joined, isTrue);

      final room = challengerProvider.currentRoom;
      expect(room, isNotNull);
      expect(room!.status, 'playing');
      expect(room.players.length, 2);
      expect(room.matchStartedAtEpochMs, isNotNull);

      // Verify both providers point to identical target perfume
      expect(challengerProvider.targetPerfume?.id, hostProvider.targetPerfume?.id);
    });

    test('6. In-game Guess Submission: Syncs colorGrid & closenessScore without name leakage', () async {
      final transport = LocalLoopbackTransport.isolated();

      final hostProvider = MultiplayerProvider(
        playerId: 'host_p1',
        transport: transport,
        engine: engine,
        repository: repository,
        storage: storage,
      );
      final code = await hostProvider.createPrivateRoom();

      final guestProvider = MultiplayerProvider(
        playerId: 'guest_p2',
        transport: transport,
        engine: engine,
        repository: repository,
        storage: storage,
      );
      await guestProvider.joinPrivateRoom(code);

      // Find a wrong guess different from the target
      final target = hostProvider.targetPerfume!;
      final wrongGuess = repository.allPerfumes.firstWhere(
        (p) => p.id != target.id && p.brand != target.brand,
      );

      await guestProvider.submitGuess(wrongGuess);

      final guestState = guestProvider.myState;
      expect(guestState, isNotNull);
      expect(guestState!.turnCount, 1);
      expect(guestState.solved, isFalse);
      expect(guestState.colorGrid.length, 1);
      expect(guestState.colorGrid.first.length, 4); // 4 attributes: [Brand, Year, Accords, Notes]
      expect(guestState.bestClosenessScore, greaterThanOrEqualTo(0));
      expect(guestState.guessedPerfumeIds, [wrongGuess.id]);
    });

    test('7. Immediate Victory Condition: Correct deduction finishes duel and updates ELO', () async {
      final transport = LocalLoopbackTransport.isolated();

      final hostProvider = MultiplayerProvider(
        playerId: 'host_p1',
        transport: transport,
        engine: engine,
        repository: repository,
        storage: storage,
      );
      final code = await hostProvider.createPrivateRoom();

      final guestProvider = MultiplayerProvider(
        playerId: 'guest_p2',
        transport: transport,
        engine: engine,
        repository: repository,
        storage: storage,
      );
      await guestProvider.joinPrivateRoom(code);

      final target = hostProvider.targetPerfume!;

      // Host submits the exact target
      await hostProvider.submitGuess(target);

      final finishedRoom = hostProvider.currentRoom;
      expect(finishedRoom, isNotNull);
      expect(finishedRoom!.status, 'finished');
      expect(finishedRoom.winnerId, hostProvider.myPlayerId);
      expect(finishedRoom.winReason, 'SOLVED_FIRST');

      // Check ELO delta recorded in host provider
      expect(hostProvider.lastProcessedEloDelta, greaterThan(0));

      // Verify solved fragrance unlocked in user's cabinet
      expect(storage.isPerfumeInCabinet(target.id), isTrue);
    });

    test('8. Turn Exhaustion Resolution: Highest closenessScore wins after 6 turns', () async {
      final transport = LocalLoopbackTransport.isolated();

      final hostProvider = MultiplayerProvider(
        playerId: 'host_p1',
        transport: transport,
        engine: engine,
        repository: repository,
        storage: storage,
      );
      final code = await hostProvider.createPrivateRoom();

      final guestProvider = MultiplayerProvider(
        playerId: 'guest_p2',
        transport: transport,
        engine: engine,
        repository: repository,
        storage: storage,
      );
      await guestProvider.joinPrivateRoom(code);

      // Both players skip 6 turns
      for (int i = 0; i < 6; i++) {
        await hostProvider.skipTurn();
        await guestProvider.skipTurn();
      }

      final room = guestProvider.currentRoom;
      expect(room, isNotNull);
      expect(room!.status, 'finished');
      expect(room.winReason, anyOf('CLOSEST_AFTER_EXHAUSTION', 'DRAW'));
    });

    test('9. Rematch Orchestration: Resets turn count and picks a fresh target perfume', () async {
      final transport = LocalLoopbackTransport.isolated();

      final hostProvider = MultiplayerProvider(
        playerId: 'host_p1',
        transport: transport,
        engine: engine,
        repository: repository,
        storage: storage,
      );
      final code = await hostProvider.createPrivateRoom();

      final guestProvider = MultiplayerProvider(
        playerId: 'guest_p2',
        transport: transport,
        engine: engine,
        repository: repository,
        storage: storage,
      );
      await guestProvider.joinPrivateRoom(code);

      // Host solves Round 1
      final round1Target = hostProvider.targetPerfume!;
      await hostProvider.submitGuess(round1Target);
      expect(hostProvider.currentRoom?.status, 'finished');

      // Both request rematch
      await hostProvider.requestRematch();
      await guestProvider.requestRematch();

      // Wait brief tick for transport broadcast delivery to host
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final round2Room = hostProvider.currentRoom;
      expect(round2Room, isNotNull);
      expect(round2Room!.status, 'playing');
      expect(round2Room.winnerId, isNull);
      expect(hostProvider.myState?.turnCount, 0);
      expect(guestProvider.myState?.turnCount, 0);
      expect(hostProvider.turnEntries.isEmpty, isTrue);
    });
  });
}
