import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/theme/scentle_theme.dart';
import '../providers/game_provider.dart';
import 'bottle_image_widget.dart';

/// Modal dialog presented when a session concludes (win or loss),
/// displaying the unblurred fragrance bottle in a pure studio container,
/// performance analytics, and viral share button.
class GameOverModal extends StatefulWidget {
  const GameOverModal({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => const GameOverModal(),
    );
  }

  @override
  State<GameOverModal> createState() => _GameOverModalState();
}

class _GameOverModalState extends State<GameOverModal> {
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 3));

    final game = context.read<GameProvider>();
    if (game.isWon) {
      _confettiController.play();
    }
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  void _shareResult(BuildContext context, ScentleThemeColors sc, GameProvider game) {
    final text = game.generateShareText();
    Clipboard.setData(ClipboardData(text: text));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Result copied to clipboard!'),
        backgroundColor: sc.ctaBackground,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameProvider>();
    final target = game.targetPerfume;
    final isWon = game.isWon;
    final stats = game.userStats;
    final sc = context.sc;

    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Dialog(
          backgroundColor: sc.cardSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: sc.border, width: 1.2),
          ),
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Victory / Defeat Header
                Text(
                  isWon ? 'EXQUISITE DEDUCTION' : 'PERFUME UNVEILED',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2.0,
                    color: isWon ? sc.exactMatch : sc.mutedText,
                  ),
                ),
                const SizedBox(height: 12),

                // Unblurred Bottle in Studio Container
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: sc.cardSurface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: sc.border),
                  ),
                  child: BottleImageWidget(
                    perfume: target,
                    blurSigma: 0.0,
                    width: 140,
                    height: 180,
                  ),
                ),
                const SizedBox(height: 14),

                // Fragrance Brand & Title
                Text(
                  target.brand.toUpperCase(),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                    color: sc.accent,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  target.name,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: sc.primaryText,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  '${target.year > 0 ? target.year : ""} • ${target.country} • ${target.gender}',
                  style: TextStyle(
                    fontSize: 12,
                    color: sc.mutedText,
                  ),
                ),
                if (target.perfumer != 'Unknown') ...[
                  const SizedBox(height: 2),
                  Text(
                    'Nose: ${target.perfumer}',
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: sc.mutedText,
                    ),
                  ),
                ],

                const SizedBox(height: 20),
                Divider(color: sc.divider),
                const SizedBox(height: 14),

                // Player Stats Bar (Played, Win %, Streak, Max)
                _buildStatsGrid(sc, stats),

                const SizedBox(height: 18),

                // Guess Distribution Chart
                _buildDistributionChart(
                  sc,
                  stats.guessDistribution,
                  game.turnEntries.length,
                  isWon,
                ),

                const SizedBox(height: 24),

                // Action Buttons
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () => _shareResult(context, sc, game),
                    icon: Icon(Icons.share, size: 18, color: sc.ctaForeground),
                    label: Text(
                      'SHARE RESULT',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                        color: sc.ctaForeground,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: sc.ctaBackground,
                      foregroundColor: sc.ctaForeground,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),

                if (game.currentMode == GameMode.unlimited) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        game.startUnlimitedGame();
                      },
                      icon: Icon(Icons.refresh, size: 18, color: sc.primaryText),
                      label: Text(
                        'PLAY NEXT FRAGRANCE',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: sc.primaryText,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: sc.primaryText,
                        side: BorderSide(color: sc.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        // Victory Confetti Animation
        if (isWon)
          ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            colors: [
              sc.accent,
              sc.exactMatch,
              Colors.white,
              const Color(0xFFE5C158),
            ],
            numberOfParticles: 28,
            gravity: 0.25,
          ),
      ],
    );
  }

  Widget _buildStatsGrid(ScentleThemeColors sc, dynamic stats) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildStatItem(sc, '${stats.gamesPlayed}', 'PLAYED'),
        _buildStatItem(sc, '${stats.winRate.toStringAsFixed(0)}%', 'WIN %'),
        _buildStatItem(sc, '${stats.currentStreak}', 'STREAK'),
        _buildStatItem(sc, '${stats.maxStreak}', 'MAX'),
      ],
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

  Widget _buildDistributionChart(
    ScentleThemeColors sc,
    Map<int, int> distribution,
    int currentTurnCount,
    bool isWon,
  ) {
    final maxCount = distribution.values.fold<int>(0, (prev, val) => val > prev ? val : prev);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                      final isCurrentWinTurn = isWon && turn == currentTurnCount;
                      final ratio = maxCount > 0 ? (count / maxCount) : 0.0;
                      final barWidth = (constraints.maxWidth * ratio).clamp(24.0, constraints.maxWidth);

                      return Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          width: barWidth,
                          height: 18,
                          decoration: BoxDecoration(
                            color: isCurrentWinTurn
                                ? sc.accent
                                : (count > 0 ? sc.ctaBackground : sc.surfaceSecondary),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            '$count',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isCurrentWinTurn
                                  ? Colors.white
                                  : (count > 0 ? sc.ctaForeground : sc.mutedText),
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
