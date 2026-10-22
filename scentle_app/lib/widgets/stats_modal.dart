import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/scentle_theme.dart';
import '../providers/game_provider.dart';
import '../services/storage_service.dart';

/// Modal displaying overall player career statistics and guess distributions.
class StatsModal extends StatelessWidget {
  const StatsModal({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => const StatsModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameProvider>();
    final stats = game.userStats;
    final cabinetCount = StorageService.instance.cabinetCount;
    final sc = context.sc;

    return Dialog(
      backgroundColor: sc.cardSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: sc.border, width: 1.2),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'CAREER STATISTICS',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      color: sc.primaryText,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, size: 20, color: sc.mutedText),
                  onPressed: () => Navigator.of(context).pop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Top Stat Counters
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(sc, '${stats.gamesPlayed}', 'PLAYED'),
                _buildStatItem(sc, '${stats.winRate.toStringAsFixed(0)}%', 'WIN %'),
                _buildStatItem(sc, '${stats.currentStreak}', 'STREAK'),
                _buildStatItem(sc, '${stats.maxStreak}', 'MAX'),
              ],
            ),

            const SizedBox(height: 16),
            Divider(color: sc.divider),
            const SizedBox(height: 12),

            // ELO and Cabinet Summary Row
            Wrap(
              alignment: WrapAlignment.spaceAround,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 6,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.shield_outlined, size: 16, color: sc.accent),
                    const SizedBox(width: 6),
                    Text(
                      'ELO: ${stats.eloRating}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: sc.primaryText,
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.inventory_2_outlined, size: 16, color: sc.accent),
                    const SizedBox(width: 6),
                    Text(
                      'Cabinet: $cabinetCount Flacons',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: sc.primaryText,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 16),
            Divider(color: sc.divider),
            const SizedBox(height: 12),

            // Distribution
            Text(
              'GUESS DISTRIBUTION',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                color: sc.mutedText,
              ),
            ),
            const SizedBox(height: 8),

            _buildDistributionBars(sc, stats.guessDistribution),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(ScentleThemeColors sc, String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: sc.primaryText,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
            color: sc.mutedText,
          ),
        ),
      ],
    );
  }

  Widget _buildDistributionBars(ScentleThemeColors sc, Map<int, int> distribution) {
    final maxCount =
        distribution.values.fold<int>(0, (prev, val) => val > prev ? val : prev);

    return Column(
      children: [
        for (int turn = 1; turn <= 6; turn++) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: Row(
              children: [
                SizedBox(
                  width: 14,
                  child: Text(
                    '$turn',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: sc.mutedText,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final count = distribution[turn] ?? 0;
                      final ratio = maxCount > 0 ? (count / maxCount) : 0.0;
                      final barWidth =
                          (constraints.maxWidth * ratio).clamp(24.0, constraints.maxWidth);

                      return Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          width: barWidth,
                          height: 18,
                          decoration: BoxDecoration(
                            color: count > 0 ? sc.ctaBackground : sc.surfaceSecondary,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            '$count',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: count > 0 ? sc.ctaForeground : sc.mutedText,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
