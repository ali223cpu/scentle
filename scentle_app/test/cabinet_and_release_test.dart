import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:scentle_app/core/theme/scentle_theme.dart';
import 'package:scentle_app/models/cabinet_entry.dart';
import 'package:scentle_app/providers/game_provider.dart';
import 'package:scentle_app/providers/multiplayer_provider.dart';
import 'package:scentle_app/screens/cabinet_screen.dart';
import 'package:scentle_app/services/multiplayer_transport.dart';
import 'package:scentle_app/services/network_time_service.dart';
import 'package:scentle_app/services/notification_service.dart';
import 'package:scentle_app/services/perfume_repository.dart';
import 'package:scentle_app/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PerfumeRepository repository;
  late StorageService storage;
  late NotificationService notificationService;

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;

    repository = PerfumeRepository.instance;
    await repository.initialize();

    storage = StorageService.instance;
    await storage.initialize();

    notificationService = NotificationService.instance;
    await notificationService.initialize();
  });

  tearDown(() async {
    await storage.clearAllBoxesForTesting();
    NetworkTimeService.instance.resetForTesting();
  });

  group('Batch 7: Scent Cabinet Trophy Collection & Auto-Unlock Flow', () {
    test('1. Winning Daily game automatically places trophy into unlocked_cabinet_box', () async {
      final gameProvider = GameProvider(
        repository: repository,
        storage: storage,
      );

      await gameProvider.startDailyGame();
      final target = gameProvider.clueState.target;

      expect(storage.isPerfumeInCabinet(target.id), isFalse);

      // Solve game with correct guess
      await gameProvider.submitGuess(target);

      expect(gameProvider.isWon, isTrue);
      expect(storage.isPerfumeInCabinet(target.id), isTrue);
      expect(storage.cabinetCount, greaterThanOrEqualTo(1));

      final entries = storage.getUnlockedCabinetEntries(repository: repository);
      expect(entries.any((e) => e.perfumeId == target.id && e.mode == 'daily'), isTrue);
    });

    test('2. Winning 1v1 Multiplayer duel automatically places trophy into cabinet with mode duel', () async {
      final transport = LocalLoopbackTransport.isolated();

      final hostProvider = MultiplayerProvider(
        playerId: 'host_trophy',
        repository: repository,
        storage: storage,
        transport: transport,
      );

      final guestProvider = MultiplayerProvider(
        playerId: 'guest_trophy',
        repository: repository,
        storage: storage,
        transport: transport,
      );

      final code = await hostProvider.createPrivateRoom(customNickname: 'Host Master');
      await guestProvider.joinPrivateRoom(code);

      final target = hostProvider.targetPerfume!;
      await hostProvider.submitGuess(target);

      expect(hostProvider.currentRoom!.status, 'finished');
      expect(hostProvider.currentRoom!.winnerId, 'host_trophy');
      expect(storage.isPerfumeInCabinet(target.id), isTrue);

      final entries = storage.getUnlockedCabinetEntries(repository: repository);
      expect(entries.any((e) => e.perfumeId == target.id && e.mode == 'duel'), isTrue);

      await hostProvider.leaveRoom();
      await guestProvider.leaveRoom();
      hostProvider.dispose();
      guestProvider.dispose();
    });

    test('3. CabinetEntry correctly deserializes and links PerfumeModel from repository', () {
      final target = repository.mysteryPool.first;
      final entry = CabinetEntry(
        perfumeId: target.id,
        unlockedAt: DateTime.utc(2026, 10, 18, 12, 0),
        mode: 'daily',
        perfume: target,
      );

      final map = entry.toMap();
      final revived = CabinetEntry.fromMap(map, perfume: repository.getById(target.id));

      expect(revived.perfumeId, target.id);
      expect(revived.mode, 'daily');
      expect(revived.modeDisplayTitle, 'Daily Scentle');
      expect(revived.perfume, isNotNull);
      expect(revived.perfume!.name, target.name);
    });
  });

  group('Batch 7: CabinetScreen UI, Filtering & BottleDetailModal', () {
    testWidgets('1. Empty cabinet displays luxury illustration, call to action, and return button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ScentleTheme.darkTheme,
          home: CabinetScreen(
            storage: storage,
            repository: repository,
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      expect(find.text('MY SCENT CABINET'), findsOneWidget);
      expect(find.text('Collected: 0 / 1229 Iconic Flacons'), findsOneWidget);
      expect(find.text('YOUR CABINET AWAITS'), findsOneWidget);
      expect(find.textContaining('Solve your first Daily Scentle'), findsOneWidget);
      expect(find.text('START TODAY\'S SCENTLE'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('2. Cabinet renders unlocked flacons, filters by mode & query, and opens dossier modal', (tester) async {
      final p1 = repository.mysteryPool[0];
      final p2 = repository.mysteryPool[1];

      // Pre-seed two trophies: one daily, one duel
      await tester.runAsync(() async {
        await storage.unlockPerfumeInCabinet(p1.id, mode: 'daily');
        await storage.unlockPerfumeInCabinet(p2.id, mode: 'duel');
      });

      // ignore: avoid_print
      await tester.pumpWidget(
        MaterialApp(
          theme: ScentleTheme.darkTheme,
          home: CabinetScreen(
            storage: storage,
            repository: repository,
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      expect(find.text('Collected: 2 / 1229 Iconic Flacons'), findsOneWidget);
      expect(find.text(p1.name), findsOneWidget);
      expect(find.text(p2.name), findsOneWidget);

      // Filter by 'Daily Wins' chip
      await tester.tap(find.text('Daily Wins'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      expect(find.text(p1.name), findsOneWidget);
      expect(find.text(p2.name), findsNothing);

      // Filter by '1v1 Trophies' chip
      await tester.tap(find.text('1v1 Trophies'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      expect(find.text(p1.name), findsNothing);
      expect(find.text(p2.name), findsOneWidget);

      // Reset to All
      await tester.tap(find.text('All'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      // Search by p1 name
      await tester.enterText(find.byType(TextField), p1.name.toLowerCase());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      expect(find.text(p1.name), findsOneWidget);
      expect(find.text(p2.name), findsNothing);

      // Tap p1 flacon card to open BottleDetailModal
      await tester.tap(find.text(p1.name).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Dossier assertions
      expect(find.text('FLACON DOSSIER'), findsOneWidget);
      expect(find.text('MAIN ACCORDS'), findsOneWidget);
      expect(find.text('OLFACTORY PYRAMID'), findsOneWidget);
      expect(find.text('RETURN TO CABINET'), findsOneWidget);

      // Dismiss dossier via close button
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('FLACON DOSSIER'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('Batch 7: Daily Streak NotificationService Scheduling & Anti-Spam', () {
    test('1. Reminder preference toggles and persists in StorageService', () async {
      expect(notificationService.isRemindersEnabled(), isTrue);

      await notificationService.setRemindersEnabled(false);
      expect(notificationService.isRemindersEnabled(), isFalse);
      expect(storage.isDailyReminderEnabled(), isFalse);
      expect(notificationService.getNextScheduledReminder(), isNull);

      await notificationService.setRemindersEnabled(true);
      expect(notificationService.isRemindersEnabled(), isTrue);
      expect(storage.isDailyReminderEnabled(), isTrue);
    });

    test('2. scheduleDailyStreakReminder schedules tomorrow at 20:00 when today is completed', () async {
      final mockNow = DateTime(2026, 10, 18, 14, 30); // 2:30 PM
      final scheduled = await notificationService.scheduleDailyStreakReminder(
        todayCompleted: true,
        currentStreak: 4,
        now: mockNow,
      );

      expect(scheduled, isNotNull);
      expect(scheduled!.year, 2026);
      expect(scheduled.month, 10);
      expect(scheduled.day, 19); // Tomorrow
      expect(scheduled.hour, 20); // 8:00 PM
      expect(scheduled.minute, 0);
    });

    test('3. scheduleDailyStreakReminder schedules tonight at 20:00 when today is uncompleted before 8 PM', () async {
      final mockNow = DateTime(2026, 10, 18, 14, 30); // 2:30 PM
      final scheduled = await notificationService.scheduleDailyStreakReminder(
        todayCompleted: false,
        currentStreak: 2,
        now: mockNow,
      );

      expect(scheduled, isNotNull);
      expect(scheduled!.year, 2026);
      expect(scheduled.month, 10);
      expect(scheduled.day, 18); // Tonight
      expect(scheduled.hour, 20); // 8:00 PM
      expect(scheduled.minute, 0);
    });

    test('4. shouldShowInAppReminderBanner respects evening window and completion state', () {
      final afternoon = DateTime(2026, 10, 18, 15, 0); // 3:00 PM
      final evening = DateTime(2026, 10, 18, 19, 0); // 7:00 PM

      // Afternoon uncompleted -> False (too early)
      expect(
        notificationService.shouldShowInAppReminderBanner(todayCompleted: false, now: afternoon),
        isFalse,
      );

      // Evening uncompleted -> True (evening reminder banner)
      expect(
        notificationService.shouldShowInAppReminderBanner(todayCompleted: false, now: evening),
        isTrue,
      );

      // Evening completed -> False (already solved)
      expect(
        notificationService.shouldShowInAppReminderBanner(todayCompleted: true, now: evening),
        isFalse,
      );
    });
  });

  group('Batch 7: Release Hardening & Firebase Security Rules', () {
    test('1. firebase_database.rules.json is valid JSON with root read/write denial and room validation', () {
      final rulesFile = File('firebase_database.rules.json');
      expect(rulesFile.existsSync(), isTrue, reason: 'firebase_database.rules.json must exist in scentle_app root');

      final content = rulesFile.readAsStringSync();
      final parsed = jsonDecode(content) as Map<String, dynamic>;

      expect(parsed.containsKey('rules'), isTrue);
      final rules = parsed['rules'] as Map<String, dynamic>;

      // Root security
      expect(rules['.read'], isFalse);
      expect(rules['.write'], isFalse);

      // Rooms security
      expect(rules.containsKey('rooms'), isTrue);
      final rooms = rules['rooms'] as Map<String, dynamic>;
      expect(rooms['.read'], isTrue);

      final roomCode = rooms['\$roomCode'] as Map<String, dynamic>;
      expect(roomCode['.write'], contains('finished'));
      expect(roomCode['.validate'], contains('targetPerfumeId'));
      expect(roomCode['.validate'], contains('length == 4'));
    });

    test('2. AndroidManifest.xml and proguard-rules.pro configure production permissions and minification', () {
      final manifestFile = File('android/app/src/main/AndroidManifest.xml');
      expect(manifestFile.existsSync(), isTrue);

      final manifestContent = manifestFile.readAsStringSync();
      expect(manifestContent.contains('android.permission.INTERNET'), isTrue);
      expect(manifestContent.contains('android.permission.ACCESS_NETWORK_STATE'), isTrue);
      expect(manifestContent.contains('android:label="Scentle"'), isTrue);

      final proguardFile = File('android/app/proguard-rules.pro');
      expect(proguardFile.existsSync(), isTrue);
      final proguardContent = proguardFile.readAsStringSync();
      expect(proguardContent.contains('io.flutter'), isTrue);
      expect(proguardContent.contains('io.hive'), isTrue);
    });
  });
}
