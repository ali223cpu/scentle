import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:scentle_app/core/theme/scentle_theme.dart';
import 'package:scentle_app/providers/game_provider.dart';
import 'package:scentle_app/screens/game_screen.dart';
import 'package:scentle_app/screens/home_screen.dart';
import 'package:scentle_app/services/perfume_repository.dart';
import 'package:scentle_app/services/storage_service.dart';
import 'package:scentle_app/widgets/bottle_image_widget.dart';
import 'package:scentle_app/widgets/guess_history_list.dart';
import 'package:scentle_app/widgets/mystery_clue_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PerfumeRepository repository;
  late StorageService storage;

  setUpAll(() async {
    // Disable runtime HTTP font fetching in test environment to avoid timeouts
    GoogleFonts.config.allowRuntimeFetching = false;

    repository = PerfumeRepository.instance;
    await repository.initialize();

    storage = StorageService.instance;
    await storage.initialize();
  });

  tearDown(() async {
    await storage.clearAllBoxesForTesting();
  });

  Widget buildTestableWidget(Widget child, GameProvider provider) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
        ChangeNotifierProvider<GameProvider>.value(value: provider),
      ],
      child: MaterialApp(
        theme: ScentleTheme.darkTheme,
        home: child,
      ),
    );
  }

  group('Batch 4 UI/UX Widget Smoke Tests', () {
    testWidgets('1. HomeScreen renders luxury brand title, metrics, and mode cards',
        (tester) async {
      final gameProvider = GameProvider(
        repository: repository,
        storage: storage,
      );
      await tester.runAsync(() async {
        await gameProvider.startDailyGame(
          utcNowOverride: DateTime.utc(2026, 10, 18),
        );
      });

      await tester.pumpWidget(
        buildTestableWidget(
          const HomeScreen(autoShowFirstLaunch: false),
          gameProvider,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('SCENTLE'), findsOneWidget);
      expect(find.text('DAILY SCENTLE'), findsOneWidget);
      expect(find.text('1v1 LIVE SPEED DUEL'), findsOneWidget);
      expect(find.text('ATELIER UNLIMITED'), findsOneWidget);
      expect(find.text('STREAK'), findsOneWidget);

      // Cleanly unmount HomeScreen to cancel periodic midnight countdown timer
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets(
        '2. GameScreen renders MysteryClueCard, accepts guesses, updates turns, and skips without overflow',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      final gameProvider = GameProvider(
        repository: repository,
        storage: storage,
      );
      await tester.runAsync(() async {
        await gameProvider.startDailyGame(
          utcNowOverride: DateTime.utc(2026, 10, 18),
        );
      });

      await tester.pumpWidget(
        buildTestableWidget(
          const GameScreen(mode: GameMode.daily),
          gameProvider,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify MysteryClueCard initial Turn 1 state
      expect(find.byType(MysteryClueCard), findsOneWidget);
      expect(find.text('TURN 1 OF 6'), findsOneWidget);
      expect(find.text('DOMINANT ACCORDS'), findsOneWidget);
      expect(find.text('🔒 Unlocks on Turn 2'), findsOneWidget);

      // Submit a wrong guess via provider
      final target = gameProvider.targetPerfume;
      final wrongGuess = repository.allPerfumes.firstWhere((p) => p.id != target.id);
      await tester.runAsync(() async {
        await gameProvider.submitGuess(wrongGuess);
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify Guess History Card renders
      expect(find.byType(GuessHistoryList), findsOneWidget);
      expect(find.text('#1'), findsOneWidget);
      expect(find.text('TURN 2 OF 6'), findsOneWidget);

      // Trigger Skip Turn
      await tester.runAsync(() async {
        await gameProvider.skipTurn();
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Turn 2 — Skipped (+1 Clue Unlocked)'), findsOneWidget);
      expect(find.text('TURN 3 OF 6'), findsOneWidget);

      // Cleanly unmount GameScreen
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('3. BottleImageWidget renders procedural luxury flacon fallback smoothly',
        (tester) async {
      final samplePerfume = repository.getById(151345)!;

      await tester.pumpWidget(
        MaterialApp(
          theme: ScentleTheme.darkTheme,
          home: Scaffold(
            body: Center(
              child: BottleImageWidget(
                perfume: samplePerfume,
                blurSigma: 18.0,
                width: 140,
                height: 180,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(BottleImageWidget), findsOneWidget);
      expect(find.byType(ImageFiltered), findsOneWidget);
    });
  });
}
