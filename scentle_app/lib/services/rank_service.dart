import 'dart:math';
import 'package:flutter/material.dart';
import '../core/theme/scentle_theme.dart';

/// Represents a luxury perfumery tier and associated visual styling.
class PerfumerRank {
  final String title;
  final IconData icon;
  final Color color;
  final int minElo;
  final int? maxElo;

  const PerfumerRank({
    required this.title,
    required this.icon,
    required this.color,
    required this.minElo,
    this.maxElo,
  });
}

/// Service governing player ELO calculations and competitive rank hierarchies.
class RankService {
  RankService._();

  static const int kFactor = 32;

  static const List<PerfumerRank> ranks = [
    PerfumerRank(
      title: 'Master Perfumer (Grand Nose)',
      icon: Icons.workspace_premium,
      color: ScentleColors.champagneGold,
      minElo: 1700,
      maxElo: null,
    ),
    PerfumerRank(
      title: 'Heart Note Specialist',
      icon: Icons.auto_awesome,
      color: Color(0xFFBA68C8),
      minElo: 1400,
      maxElo: 1699,
    ),
    PerfumerRank(
      title: 'Atelier Evaluator',
      icon: Icons.colorize_outlined,
      color: Color(0xFF64B5F6),
      minElo: 1200,
      maxElo: 1399,
    ),
    PerfumerRank(
      title: 'Accord Apprentice',
      icon: Icons.eco_outlined,
      color: Color(0xFF81C784),
      minElo: 1000,
      maxElo: 1199,
    ),
    PerfumerRank(
      title: 'Test Strip Novice',
      icon: Icons.science_outlined,
      color: Color(0xFF9E9E9E),
      minElo: 0,
      maxElo: 999,
    ),
  ];

  /// Resolves the perfumer rank corresponding to the specified ELO rating.
  static PerfumerRank getRank(int elo) {
    for (final rank in ranks) {
      if (elo >= rank.minElo) {
        return rank;
      }
    }
    return ranks.last;
  }

  /// Calculates the ELO rating delta for a match.
  /// [outcome] is 1.0 for a win, 0.5 for a draw, and 0.0 for a loss.
  static int calculateEloDelta({
    required int myElo,
    required int opponentElo,
    required double outcome,
    int k = kFactor,
  }) {
    // Expected score formula: 1 / (1 + 10^((opp - my) / 400))
    final exponent = (opponentElo - myElo) / 400.0;
    final expectedScore = 1.0 / (1.0 + pow(10.0, exponent));
    final delta = (k * (outcome - expectedScore)).round();

    // Guard against zero-change on pure win or pure loss
    if (outcome == 1.0 && delta == 0) return 1;
    if (outcome == 0.0 && delta == 0) return -1;

    return delta;
  }
}
