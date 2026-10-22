import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../core/utils/platform_env.dart' as platform_env;
import '../models/cabinet_entry.dart';
import '../models/user_stats.dart';
import 'perfume_repository.dart';

/// Clean wrapper around Hive NoSQL local storage for Scentle.
/// Manages boxes for daily progress, player stats, unlocked collection, and settings.
class StorageService {
  static final StorageService instance = StorageService._internal();

  StorageService._internal();

  static const String boxDailyProgress = 'daily_progress_box';
  static const String boxUserStats = 'user_stats_box';
  static const String boxUnlockedCabinet = 'unlocked_cabinet_box';
  static const String boxSettings = 'settings_box';

  static const String _keyUserStats = 'user_stats_payload';

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  late Box<dynamic> dailyProgressBox;
  late Box<dynamic> userStatsBox;
  late Box<dynamic> unlockedCabinetBox;
  late Box<dynamic> settingsBox;

  /// Initializes Hive Flutter and opens all persistent game boxes.
  Future<void> initialize({String? customPath}) async {
    if (_isInitialized) return;

    if (customPath != null) {
      Hive.init(customPath);
    } else {
      try {
        await Hive.initFlutter();
      } catch (_) {
        // Fallback for headless CLI unit test runners where path_provider is unavailable
        final tempPath = platform_env.getSystemTempPath();
        if (tempPath != null) {
          Hive.init(tempPath);
        }
      }
    }

    dailyProgressBox = await Hive.openBox<dynamic>(boxDailyProgress);
    userStatsBox = await Hive.openBox<dynamic>(boxUserStats);
    unlockedCabinetBox = await Hive.openBox<dynamic>(boxUnlockedCabinet);
    settingsBox = await Hive.openBox<dynamic>(boxSettings);

    await _seedDefaults();

    _isInitialized = true;
  }

  // ===========================================================================
  // Daily Progress Persistence
  // ===========================================================================

  /// Persists the active or completed daily game state for a given UTC date.
  Future<void> saveDailyProgress({
    required String dateStr,
    required int targetId,
    required List<Map<String, dynamic>> entries,
    required bool isWon,
    required bool isGameOver,
    required bool bonusNoteRevealed,
  }) async {
    final payload = {
      'date': dateStr,
      'targetId': targetId,
      'entries': entries,
      'isWon': isWon,
      'isGameOver': isGameOver,
      'bonusNoteRevealed': bonusNoteRevealed,
    };
    await dailyProgressBox.put(dateStr, payload);
  }

  /// Retrieves the saved daily progress for a given date, or null if unplayed.
  Map<String, dynamic>? getDailyProgress(String dateStr) {
    final dynamic data = dailyProgressBox.get(dateStr);
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return null;
  }

  /// Returns true if a daily game has been recorded for the specified date.
  bool hasPlayedDaily(String dateStr) {
    return dailyProgressBox.containsKey(dateStr);
  }

  // ===========================================================================
  // User Stats Persistence
  // ===========================================================================

  /// Retrieves user stats from Hive, returning a fresh default instance if absent.
  UserStats getUserStats() {
    final dynamic raw = userStatsBox.get(_keyUserStats);
    if (raw is Map) {
      return UserStats.fromJson(raw);
    }
    return UserStats();
  }

  /// Persists updated user statistics to Hive.
  Future<void> saveUserStats(UserStats stats) async {
    await userStatsBox.put(_keyUserStats, stats.toJson());
  }

  // ===========================================================================
  // Unlocked Scent Cabinet Persistence
  // ===========================================================================

  /// Records a solved perfume into the player's permanent collection cabinet.
  Future<void> unlockPerfumeInCabinet(
    int perfumeId, {
    required String mode,
  }) async {
    final key = perfumeId.toString();
    if (!unlockedCabinetBox.containsKey(key)) {
      final payload = {
        'perfumeId': perfumeId,
        'unlockedAt': DateTime.now().toUtc().toIso8601String(),
        'mode': mode,
      };
      await unlockedCabinetBox.put(key, payload);
    }
  }

  /// Returns true if the perfume exists in the player's unlocked cabinet.
  bool isPerfumeInCabinet(int perfumeId) {
    return unlockedCabinetBox.containsKey(perfumeId.toString());
  }

  /// Returns all unlocked cabinet entries.
  List<Map<String, dynamic>> getUnlockedCabinet() {
    final list = <Map<String, dynamic>>[];
    for (final key in unlockedCabinetBox.keys) {
      final val = unlockedCabinetBox.get(key);
      if (val is Map) {
        list.add(Map<String, dynamic>.from(val));
      }
    }
    return list;
  }

  /// Returns all unlocked cabinet entries as strongly-typed [CabinetEntry] objects, sorted newest-first.
  List<CabinetEntry> getUnlockedCabinetEntries({PerfumeRepository? repository}) {
    final list = <CabinetEntry>[];
    for (final key in unlockedCabinetBox.keys) {
      final val = unlockedCabinetBox.get(key);
      if (val is Map) {
        final map = Map<String, dynamic>.from(val);
        final perfumeId = map['perfumeId'] as int? ?? int.tryParse(key.toString()) ?? 0;
        final perfume = repository?.getById(perfumeId);
        list.add(CabinetEntry.fromMap(map, perfume: perfume));
      }
    }
    list.sort((a, b) => b.unlockedAt.compareTo(a.unlockedAt));
    return list;
  }

  int get cabinetCount => unlockedCabinetBox.length;

  // ===========================================================================
  // Player Profile / Identity
  // ===========================================================================

  static const String _keyPlayerId = 'scentle_player_id';
  static const String _keyPlayerNickname = 'scentle_player_nickname';

  /// Retrieves the saved unique player ID, or generates and saves a new one.
  String getOrCreatePlayerId() {
    final dynamic stored = settingsBox.get(_keyPlayerId);
    if (stored is String && stored.isNotEmpty) {
      return stored;
    }
    final newId = 'nose_${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}';
    settingsBox.put(_keyPlayerId, newId);
    return newId;
  }

  /// Retrieves the saved nickname, or returns a default formatted name.
  String getPlayerNickname() {
    final dynamic stored = settingsBox.get(_keyPlayerNickname);
    if (stored is String && stored.trim().isNotEmpty) {
      return stored.trim();
    }
    final id = getOrCreatePlayerId();
    final suffix = id.length > 4 ? id.substring(id.length - 4).toUpperCase() : '777';
    final defaultName = 'Nose_$suffix';
    settingsBox.put(_keyPlayerNickname, defaultName);
    return defaultName;
  }

  /// Saves the player's custom nickname.
  Future<void> savePlayerNickname(String nickname) async {
    await settingsBox.put(_keyPlayerNickname, nickname.trim());
  }

  // ===========================================================================
  // Settings & Preferences
  // ===========================================================================

  static const String _keyIsFirstLaunch = 'is_first_launch';
  static const String _keyHapticEnabled = 'haptic_enabled';
  static const String _keySoundEnabled = 'sound_enabled';

  /// Returns true if this is the player's first app launch.
  bool isFirstLaunch() {
    return settingsBox.get(_keyIsFirstLaunch, defaultValue: true) as bool;
  }

  /// Flags first launch onboarding as completed.
  Future<void> setFirstLaunchCompleted() async {
    await settingsBox.put(_keyIsFirstLaunch, false);
  }

  /// Returns whether haptic feedback is enabled.
  bool isHapticEnabled() {
    return settingsBox.get(_keyHapticEnabled, defaultValue: true) as bool;
  }

  /// Updates haptic feedback setting.
  Future<void> setHapticEnabled(bool enabled) async {
    await settingsBox.put(_keyHapticEnabled, enabled);
  }

  /// Returns whether sound effects are enabled.
  bool isSoundEnabled() {
    return settingsBox.get(_keySoundEnabled, defaultValue: true) as bool;
  }

  /// Updates sound effects setting.
  Future<void> setSoundEnabled(bool enabled) async {
    await settingsBox.put(_keySoundEnabled, enabled);
  }

  static const String _keyDailyReminderEnabled = 'daily_reminder_enabled';
  static const String _keyNextReminderEpochMs = 'next_reminder_epoch_ms';
  static const String _keyLastReminderScheduledEpochMs = 'last_reminder_scheduled_epoch_ms';

  /// Returns whether daily 8:00 PM streak reminders are enabled.
  bool isDailyReminderEnabled() {
    return settingsBox.get(_keyDailyReminderEnabled, defaultValue: true) as bool;
  }

  /// Updates daily streak reminder preference.
  Future<void> setDailyReminderEnabled(bool enabled) async {
    await settingsBox.put(_keyDailyReminderEnabled, enabled);
  }

  /// Returns the next scheduled reminder time in local epoch ms.
  int? getNextReminderEpochMs() {
    final dynamic val = settingsBox.get(_keyNextReminderEpochMs);
    return val is int ? val : null;
  }

  /// Sets the next scheduled reminder time in local epoch ms.
  Future<void> setNextReminderEpochMs(int? epochMs) async {
    if (epochMs == null) {
      await settingsBox.delete(_keyNextReminderEpochMs);
    } else {
      await settingsBox.put(_keyNextReminderEpochMs, epochMs);
    }
  }

  /// Returns the last reminder scheduled epoch ms.
  int? getLastReminderScheduledEpochMs() {
    final dynamic val = settingsBox.get(_keyLastReminderScheduledEpochMs);
    return val is int ? val : null;
  }

  /// Sets the last reminder scheduled epoch ms.
  Future<void> setLastReminderScheduledEpochMs(int? epochMs) async {
    if (epochMs == null) {
      await settingsBox.delete(_keyLastReminderScheduledEpochMs);
    } else {
      await settingsBox.put(_keyLastReminderScheduledEpochMs, epochMs);
    }
  }

  Future<void> _seedDefaults() async {
    if (!settingsBox.containsKey(_keyPlayerId)) {
      final newId = 'nose_${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}';
      await settingsBox.put(_keyPlayerId, newId);
    }
    if (!settingsBox.containsKey(_keyPlayerNickname)) {
      final id = settingsBox.get(_keyPlayerId) as String;
      final suffix = id.length > 4 ? id.substring(id.length - 4).toUpperCase() : '777';
      await settingsBox.put(_keyPlayerNickname, 'Nose_$suffix');
    }
  }

  /// Test utility to purge box contents.
  @visibleForTesting
  Future<void> clearAllBoxesForTesting() async {
    if (_isInitialized) {
      await dailyProgressBox.clear();
      await userStatsBox.clear();
      await unlockedCabinetBox.clear();
      await settingsBox.clear();
      await _seedDefaults();
    }
  }

  /// Closes all open boxes safely on shutdown.
  Future<void> dispose() async {
    await Hive.close();
    _isInitialized = false;
  }
}
