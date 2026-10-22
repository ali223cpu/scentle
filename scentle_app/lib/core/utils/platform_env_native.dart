import 'dart:io';

/// Native (VM / CLI / Unit Tests) implementation of platform I/O.
String? getSystemTempPath() {
  final tempDir = Directory.systemTemp.createTempSync('scentle_hive_test_');
  return tempDir.path;
}

Future<String?> readFileAsString(String path) async {
  final file = File(path);
  if (await file.exists()) {
    return await file.readAsString();
  }
  return null;
}
