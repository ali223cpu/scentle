import 'dart:math';

/// Player game statistics, streak tracking, and guess distribution.
class UserStats {
  int gamesPlayed;
  int gamesWon;
  int currentStreak;
  int maxStreak;
  String? lastPlayedUtcDate;
  String? lastWonUtcDate;
  Map<int, int> guessDistribution;
  int eloRating;

  UserStats({
    this.gamesPlayed = 0,
    this.gamesWon = 0,
    this.currentStreak = 0,
    this.maxStreak = 0,
    this.lastPlayedUtcDate,
    this.lastWonUtcDate,
    Map<int, int>? guessDistribution,
    this.eloRating = 1000,
  }) : guessDistribution = guessDistribution ?? {1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0};

  double get winRate =>
      gamesPlayed > 0 ? (gamesWon / gamesPlayed) * 100.0 : 0.0;

  /// Records a victory, computing streak continuity and updating distribution.
  void recordGameWon({
    required String utcDateStr,
    required int turnCount,
  }) {
    gamesPlayed += 1;
    gamesWon += 1;

    // Check streak continuity
    if (lastWonUtcDate != null) {
      try {
        final last = DateTime.parse(lastWonUtcDate!);
        final current = DateTime.parse(utcDateStr);
        final diff = current.difference(last).inDays;

        if (diff == 1) {
          currentStreak += 1;
        } else if (diff == 0) {
          // Same calendar date played (e.g. unlimited after daily), maintain streak
        } else {
          // Missed at least one day
          currentStreak = 1;
        }
      } catch (_) {
        currentStreak = 1;
      }
    } else {
      currentStreak = 1;
    }

    maxStreak = max(maxStreak, currentStreak);
    lastWonUtcDate = utcDateStr;
    lastPlayedUtcDate = utcDateStr;

    final clampedTurn = turnCount.clamp(1, 6);
    guessDistribution[clampedTurn] = (guessDistribution[clampedTurn] ?? 0) + 1;
  }

  /// Records a defeat and breaks the active streak.
  void recordGameLost({
    required String utcDateStr,
  }) {
    gamesPlayed += 1;
    currentStreak = 0;
    lastPlayedUtcDate = utcDateStr;
  }

  Map<String, dynamic> toJson() => {
        'gamesPlayed': gamesPlayed,
        'gamesWon': gamesWon,
        'currentStreak': currentStreak,
        'maxStreak': maxStreak,
        'lastPlayedUtcDate': lastPlayedUtcDate,
        'lastWonUtcDate': lastWonUtcDate,
        'guessDistribution': guessDistribution.map((k, v) => MapEntry(k.toString(), v)),
        'eloRating': eloRating,
      };

  factory UserStats.fromJson(Map<dynamic, dynamic>? json) {
    if (json == null) return UserStats();

    final distMap = <int, int>{1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0};
    if (json['guessDistribution'] is Map) {
      final rawDist = json['guessDistribution'] as Map;
      rawDist.forEach((k, v) {
        final keyInt = int.tryParse(k.toString());
        final valInt = int.tryParse(v.toString());
        if (keyInt != null && valInt != null && keyInt >= 1 && keyInt <= 6) {
          distMap[keyInt] = valInt;
        }
      });
    }

    return UserStats(
      gamesPlayed: json['gamesPlayed'] as int? ?? 0,
      gamesWon: json['gamesWon'] as int? ?? 0,
      currentStreak: json['currentStreak'] as int? ?? 0,
      maxStreak: json['maxStreak'] as int? ?? 0,
      lastPlayedUtcDate: json['lastPlayedUtcDate']?.toString(),
      lastWonUtcDate: json['lastWonUtcDate']?.toString(),
      guessDistribution: distMap,
      eloRating: json['eloRating'] as int? ?? 1000,
    );
  }
}
