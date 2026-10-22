import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:scentle_app/core/theme/scentle_theme.dart';
import 'package:scentle_app/providers/game_provider.dart';
import 'package:scentle_app/providers/multiplayer_provider.dart';
import 'package:scentle_app/screens/cabinet_screen.dart';
import 'package:scentle_app/screens/game_screen.dart';
import 'package:scentle_app/screens/home_screen.dart';
import 'package:scentle_app/screens/multiplayer_lobby_screen.dart';
import 'package:scentle_app/services/perfume_repository.dart';
import 'package:scentle_app/services/storage_service.dart';
import 'package:scentle_app/widgets/settings_modal.dart';
import 'package:scentle_app/widgets/stats_modal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PerfumeRepository repository;
  late StorageService storage;

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    repository = PerfumeRepository.instance;
    await repository.initialize();

    storage = StorageService.instance;
    await storage.initialize();
  });

  tearDown(() async {
    await storage.clearAllBoxesForTesting();
  });

  Widget buildTestableApp({
    required Widget child,
    required GameProvider gameProvider,
    MultiplayerProvider? multiplayerProvider,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
        ChangeNotifierProvider<GameProvider>.value(value: gameProvider),
        if (multiplayerProvider != null)
          ChangeNotifierProvider<MultiplayerProvider>.value(value: multiplayerProvider),
      ],
      child: MaterialApp(
        theme: ScentleTheme.warmAtelierTheme,
        home: child,
      ),
    );
  }

  void setViewport(WidgetTester tester, {required double width, required double height}) {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1.0;
  }

  group('Mobile Viewport & Overflow Tests (320px - 390px widths)', () {
    testWidgets('1. HomeScreen renders without overflow on 320x568 compact viewport',
        (tester) async {
      setViewport(tester, width: 320, height: 568);
      addTearDown(tester.view.resetPhysicalSize);

      final gameProvider = GameProvider(repository: repository, storage: storage);
      await tester.runAsync(() async {
        await gameProvider.startDailyGame(utcNowOverride: DateTime.utc(2026, 10, 18));
      });

      await tester.pumpWidget(
        buildTestableApp(
          child: const HomeScreen(autoShowFirstLaunch: false),
          gameProvider: gameProvider,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
      expect(find.text('SCENTLE'), findsOneWidget);
      expect(find.text('DAILY SCENTLE'), findsOneWidget);
      expect(find.text('1v1 LIVE SPEED DUEL'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('2. GameScreen renders without overflow on 320x568 compact viewport',
        (tester) async {
      setViewport(tester, width: 320, height: 568);
      addTearDown(tester.view.resetPhysicalSize);

      final gameProvider = GameProvider(repository: repository, storage: storage);
      await tester.runAsync(() async {
        await gameProvider.startDailyGame(utcNowOverride: DateTime.utc(2026, 10, 18));
      });

      await tester.pumpWidget(
        buildTestableApp(
          child: const GameScreen(mode: GameMode.daily),
          gameProvider: gameProvider,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
      expect(find.text('TURN 1 OF 6'), findsOneWidget);
      expect(find.text('DOMINANT ACCORDS'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('3. MultiplayerLobbyScreen renders without overflow on 320x568 compact viewport',
        (tester) async {
      setViewport(tester, width: 320, height: 568);
      addTearDown(tester.view.resetPhysicalSize);

      final gameProvider = GameProvider(repository: repository, storage: storage);
      final multiplayerProvider = MultiplayerProvider();

      await tester.pumpWidget(
        buildTestableApp(
          child: const MultiplayerLobbyScreen(),
          gameProvider: gameProvider,
          multiplayerProvider: multiplayerProvider,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
      expect(find.text('1v1 SPEED DUEL'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('4. CabinetScreen renders without overflow on 320x568 compact viewport',
        (tester) async {
      setViewport(tester, width: 320, height: 568);
      addTearDown(tester.view.resetPhysicalSize);

      final gameProvider = GameProvider(repository: repository, storage: storage);

      await tester.pumpWidget(
        buildTestableApp(
          child: CabinetScreen(storage: storage, repository: repository),
          gameProvider: gameProvider,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
      expect(find.text('MY SCENT CABINET'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('5. SettingsModal and StatsModal render without overflow on 320x568 compact viewport',
        (tester) async {
      setViewport(tester, width: 320, height: 568);
      addTearDown(tester.view.resetPhysicalSize);

      final gameProvider = GameProvider(repository: repository, storage: storage);
      await tester.runAsync(() async {
        await gameProvider.startDailyGame(utcNowOverride: DateTime.utc(2026, 10, 18));
      });
      final multiplayerProvider = MultiplayerProvider();

      // Test SettingsModal
      await tester.pumpWidget(
        buildTestableApp(
          child: const Scaffold(body: SettingsModal()),
          gameProvider: gameProvider,
          multiplayerProvider: multiplayerProvider,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
      expect(find.text('ATELIER SETTINGS'), findsOneWidget);

      // Test StatsModal
      await tester.pumpWidget(
        buildTestableApp(
          child: const Scaffold(body: StatsModal()),
          gameProvider: gameProvider,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
      expect(find.text('CAREER STATISTICS'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
