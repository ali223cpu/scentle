import 'package:scentle_app/models/perfume_model.dart';

/// Immutable record of an unlocked perfume trophy in the player's scent cabinet.
class CabinetEntry {
  final int perfumeId;
  final DateTime unlockedAt;
  final String mode; // 'daily', 'duel', 'unlimited'
  final PerfumeModel? perfume;

  const CabinetEntry({
    required this.perfumeId,
    required this.unlockedAt,
    required this.mode,
    this.perfume,
  });

  /// Human-readable presentation badge for the mode.
  String get modeDisplayTitle {
    switch (mode.toLowerCase()) {
      case 'daily':
        return 'Daily Scentle';
      case 'duel':
        return '1v1 Duel';
      case 'unlimited':
      case 'atelier':
        return 'Atelier Practice';
      default:
        return mode.toUpperCase();
    }
  }

  factory CabinetEntry.fromMap(Map<String, dynamic> map, {PerfumeModel? perfume}) {
    return CabinetEntry(
      perfumeId: map['perfumeId'] as int? ?? 0,
      unlockedAt: DateTime.tryParse(map['unlockedAt'] as String? ?? '') ?? DateTime.now(),
      mode: map['mode'] as String? ?? 'daily',
      perfume: perfume,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'perfumeId': perfumeId,
      'unlockedAt': unlockedAt.toIso8601String(),
      'mode': mode,
    };
  }

  CabinetEntry copyWith({
    int? perfumeId,
    DateTime? unlockedAt,
    String? mode,
    PerfumeModel? perfume,
  }) {
    return CabinetEntry(
      perfumeId: perfumeId ?? this.perfumeId,
      unlockedAt: unlockedAt ?? this.unlockedAt,
      mode: mode ?? this.mode,
      perfume: perfume ?? this.perfume,
    );
  }
}
