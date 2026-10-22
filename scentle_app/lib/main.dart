import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/scentle_theme.dart';
import 'providers/game_provider.dart';
import 'providers/multiplayer_provider.dart';
import 'screens/home_screen.dart';
import 'services/network_time_service.dart';
import 'services/notification_service.dart';
import 'services/perfume_repository.dart';
import 'services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ScentleRootApp());
}

/// Root application widget wrapping global providers and theme configuration.
class ScentleRootApp extends StatelessWidget {
  const ScentleRootApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>(
          create: (_) => ThemeProvider(),
        ),
        ChangeNotifierProvider<GameProvider>(
          create: (_) => GameProvider(),
        ),
        ChangeNotifierProvider<MultiplayerProvider>(
          create: (_) => MultiplayerProvider(),
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'Scentle',
            debugShowCheckedModeBanner: false,
            theme: ScentleTheme.warmAtelierTheme,
            darkTheme: ScentleTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            // Smooth 300ms animated theme transition
            themeAnimationDuration: const Duration(milliseconds: 300),
            themeAnimationCurve: Curves.easeInOut,
            home: const ScentleBootstrapGate(),
          );
        },
      ),
    );
  }
}

/// Initial gate screen that initializes Hive storage and loads the 4.46 MB
/// in-memory fragrance database before navigating to HomeScreen.
class ScentleBootstrapGate extends StatefulWidget {
  const ScentleBootstrapGate({super.key});

  @override
  State<ScentleBootstrapGate> createState() => _ScentleBootstrapGateState();
}

class _ScentleBootstrapGateState extends State<ScentleBootstrapGate> {
  bool _isLoading = true;
  String _statusText = 'Awakening olfactory archive...';

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      await StorageService.instance.initialize();
      await NotificationService.instance.initialize();
      unawaited(NetworkTimeService.instance.syncNetworkTime());

      // Hydrate persisted theme preference after storage is ready
      if (mounted) {
        context.read<ThemeProvider>().loadFromStorage(
          StorageService.instance.settingsBox,
        );
      }

      if (mounted) setState(() => _statusText = 'Indexing 12,280 fragrances...');

      await PerfumeRepository.instance.initialize();

      // Pre-warm daily game state
      if (mounted) {
        await context.read<GameProvider>().startDailyGame();
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _statusText = 'Initialization error: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoading) {
      return const HomeScreen();
    }

    final sc = context.sc;

    return Scaffold(
      backgroundColor: sc.scaffoldBg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'SCENTLE',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  color: sc.accent,
                  letterSpacing: 4.0,
                  fontSize: 36,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'GRASSE • PARIS • NEW YORK',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.5,
                  fontFamily: 'monospace',
                  color: sc.mutedText,
                ),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(sc.accent),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                _statusText,
                style: TextStyle(
                  fontSize: 12,
                  color: sc.mutedText,
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
