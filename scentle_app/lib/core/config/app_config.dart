/// Application configuration constants and compile-time environment variables.
class AppConfig {
  AppConfig._();

  /// Configurable Firebase Realtime Database URL.
  /// If empty, Multiplayer auto-selects the local loopback transport for $0 offline testing.
  static const String firebaseRealtimeDbUrl = String.fromEnvironment(
    'FIREBASE_DB_URL',
    defaultValue: '',
  );

  /// Master match clock in seconds (2 minutes).
  static const int matchDurationSeconds = 120;

  /// Per-turn stall / AFK protection in seconds.
  static const int afkTimeoutSeconds = 35;
}
