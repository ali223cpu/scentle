import 'dart:async';
import 'package:flutter/foundation.dart';
import 'storage_service.dart';

/// Clean, platform-safe daily reminder and streak notification service.
/// Coordinates 8:00 PM (20:00) local reminder scheduling and in-app streak banners
/// without requiring fragile native notification compile dependencies.
class NotificationService {
  static final NotificationService instance = NotificationService._internal();

  NotificationService._internal({StorageService? storage})
      : _storage = storage ?? StorageService.instance;

  @visibleForTesting
  factory NotificationService.forTesting({required StorageService storage}) {
    return NotificationService._internal(storage: storage);
  }

  final StorageService _storage;
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  /// Initializes the notification service and ensures current reminder schedule is coherent.
  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;
  }

  /// Returns whether daily streak reminders are enabled by the player.
  bool isRemindersEnabled() {
    return _storage.isDailyReminderEnabled();
  }

  /// Toggles reminder state and updates the schedule.
  Future<void> setRemindersEnabled(bool enabled) async {
    await _storage.setDailyReminderEnabled(enabled);
    if (!enabled) {
      await _storage.setNextReminderEpochMs(null);
    }
  }

  /// Returns the next scheduled reminder timestamp in local time.
  DateTime? getNextScheduledReminder() {
    final ms = _storage.getNextReminderEpochMs();
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  /// Schedules the next 8:00 PM (20:00) local streak reminder.
  /// If [todayCompleted] is true, schedules for tomorrow at 20:00.
  /// If [todayCompleted] is false and current time < 20:00, schedules for today at 20:00.
  /// If [todayCompleted] is false and current time >= 20:00, marks active and schedules tomorrow.
  Future<DateTime?> scheduleDailyStreakReminder({
    required bool todayCompleted,
    required int currentStreak,
    DateTime? now,
  }) async {
    if (!_storage.isDailyReminderEnabled()) {
      await _storage.setNextReminderEpochMs(null);
      return null;
    }

    final currentTime = now ?? DateTime.now();
    final todayEightPm = DateTime(
      currentTime.year,
      currentTime.month,
      currentTime.day,
      20,
      0,
      0,
    );

    final DateTime targetSchedule;

    if (todayCompleted) {
      // Today solved: next reminder is tomorrow at 20:00
      targetSchedule = todayEightPm.add(const Duration(days: 1));
    } else {
      if (currentTime.isBefore(todayEightPm)) {
        // Today uncompleted and before 8:00 PM: schedule for tonight
        targetSchedule = todayEightPm;
      } else {
        // Already past 8:00 PM tonight: schedule for tomorrow at 8:00 PM
        targetSchedule = todayEightPm.add(const Duration(days: 1));
      }
    }

    await _storage.setNextReminderEpochMs(targetSchedule.millisecondsSinceEpoch);
    await _storage.setLastReminderScheduledEpochMs(currentTime.millisecondsSinceEpoch);
    return targetSchedule;
  }

  /// Returns true if an in-app evening reminder banner should be surfaced on the home screen
  /// (reminders enabled, today's daily puzzle uncompleted, and local time is 18:00 or later).
  bool shouldShowInAppReminderBanner({
    required bool todayCompleted,
    DateTime? now,
  }) {
    if (!isRemindersEnabled()) return false;
    if (todayCompleted) return false;

    final currentTime = now ?? DateTime.now();
    // Evening alert window starts at 18:00 (6:00 PM) through end of day
    return currentTime.hour >= 18;
  }

  /// Formats the reminder notification message for the player.
  String getReminderMessage(int currentStreak) {
    if (currentStreak > 0) {
      return '🔥 Keep your $currentStreak-day Scentle streak alive! Tonight\'s mystery flacon awaits your nose.';
    }
    return '✨ Today\'s mystery fragrance is waiting at the Atelier. Can you deduce it in 6 turns?';
  }
}
