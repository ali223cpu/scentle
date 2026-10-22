import 'platform_env_stub.dart'
    if (dart.library.io) 'platform_env_native.dart' as platform_env;

/// Returns system temp path for headless test suites or null on web.
String? getSystemTempPath() => platform_env.getSystemTempPath();

/// Reads file as string from filesystem or returns null on web.
Future<String?> readFileAsString(String path) => platform_env.readFileAsString(path);
