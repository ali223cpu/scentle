import 'package:flutter/material.dart';
import '../core/theme/scentle_theme.dart';
import '../models/multiplayer_room.dart';
import '../services/rank_service.dart';

/// Real-time top HUD widget displaying the 120-second master match clock,
/// player progress, and live spoiler-free opponent color matrix.
/// Styled in dark espresso (#161514) to contrast crisply against the board.
class LiveOpponentHudWidget extends StatelessWidget {
  final MultiplayerPlayerState? myState;
  final MultiplayerPlayerState? opponentState;
  final int remainingSeconds;

  const LiveOpponentHudWidget({
    super.key,
    required this.myState,
    required this.opponentState,
    required this.remainingSeconds,
  });

  String _formatTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final sc = context.sc;
    final isCriticalTime = remainingSeconds <= 20;
    final timeColor = isCriticalTime ? const Color(0xFFEF4444) : sc.accent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF161514), // Dark espresso pinned HUD
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCriticalTime
              ? const Color(0xFFEF4444).withValues(alpha: 0.6)
              : const Color(0xFF2E2C29),
          width: 1.2,
        ),
        boxShadow: [
          if (isCriticalTime)
            BoxShadow(
              color: const Color(0xFFEF4444).withValues(alpha: 0.25),
              blurRadius: 16,
              spreadRadius: 2,
            )
          else
            const BoxShadow(
              color: Color(0x2A000000),
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
        ],
      ),
      child: Row(
        children: [
          // Left: Local Player Summary (YOU)
          Expanded(
            child: _buildPlayerColumn(
              sc: sc,
              nickname: myState?.nickname ?? 'You',
              elo: myState?.elo ?? 1000,
              turnCount: myState?.turnCount ?? 0,
              bestScore: myState?.bestClosenessScore ?? 0,
              isSolved: myState?.solved ?? false,
              isMe: true,
            ),
          ),

          // Center: Master Match Clock (Gold-bordered clock)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF0F0E0D),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: timeColor.withValues(alpha: 0.8), width: 1.2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.timer_outlined,
                  size: 13,
                  color: timeColor,
                ),
                const SizedBox(height: 2),
                Text(
                  _formatTime(remainingSeconds),
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: timeColor,
                  ),
                ),
              ],
            ),
          ),

          // Right: Opponent Summary + 4x6 Mini Matrix
          Expanded(
            child: _buildOpponentColumn(
              sc: sc,
              opponent: opponentState,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerColumn({
    required ScentleThemeColors sc,
    required String nickname,
    required int elo,
    required int turnCount,
    required int bestScore,
    required bool isSolved,
    required bool isMe,
  }) {
    final rank = RankService.getRank(elo);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(rank.icon, size: 12, color: rank.color),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                nickname,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFAF7F2), // Alabaster white text on espresso HUD
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 6,
          runSpacing: 2,
          children: [
            Text(
              'TURN $turnCount/6',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isSolved ? sc.exactMatch : const Color(0xFF9E9B93),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: const Color(0xFF262422),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '$bestScore pts',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: sc.accent,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOpponentColumn({
    required ScentleThemeColors sc,
    required MultiplayerPlayerState? opponent,
  }) {
    if (opponent == null) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Waiting for challenger...',
            style: TextStyle(fontSize: 11, color: Color(0xFF9E9B93)),
          ),
        ],
      );
    }

    final rank = RankService.getRank(opponent.elo);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                opponent.nickname,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFAF7F2),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(rank.icon, size: 12, color: rank.color),
          ],
        ),
        const SizedBox(height: 3),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.end,
          spacing: 6,
          runSpacing: 2,
          children: [
            _buildMiniMatrix(sc, opponent.colorGrid),
            Text(
              '${opponent.bestClosenessScore} pts',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: sc.accent,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Builds the 4-column live miniature matrix showing opponent's guess colors
  Widget _buildMiniMatrix(ScentleThemeColors sc, List<List<String>> colorGrid) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(6, (turnIdx) {
        final hasTurn = turnIdx < colorGrid.length;
        final turnColors = hasTurn ? colorGrid[turnIdx] : null;

        return Padding(
          padding: const EdgeInsets.only(left: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(4, (tileIdx) {
              Color tileColor = const Color(0xFF383531);
              if (turnColors != null && tileIdx < turnColors.length) {
                final status = turnColors[tileIdx];
                if (status == 'EXACT') {
                  tileColor = sc.exactMatch;
                } else if (status == 'CLOSE') {
                  tileColor = sc.closeMatch;
                } else {
                  tileColor = const Color(0xFF5E5953);
                }
              }

              return Container(
                width: 3.5,
                height: 3.5,
                margin: const EdgeInsets.symmetric(vertical: 0.5),
                decoration: BoxDecoration(
                  color: tileColor,
                  borderRadius: BorderRadius.circular(1),
                ),
              );
            }),
          ),
        );
      }),
    );
  }
}
