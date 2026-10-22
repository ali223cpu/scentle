import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/scentle_theme.dart';
import '../models/multiplayer_room.dart';
import '../models/perfume_model.dart';
import '../providers/multiplayer_provider.dart';
import '../services/perfume_repository.dart';
import '../services/rank_service.dart';
import '../services/storage_service.dart';
import 'bottle_image_widget.dart';

/// Luxury post-match modal for 1v1 speed duels.
/// Displays victor outcome, ELO rating adjustments, unblurred bottle,
/// side-by-side guess comparisons, and rematch orchestration.
class MultiplayerResultModal extends StatelessWidget {
  final MultiplayerRoom room;
  final PerfumeModel targetPerfume;
  final VoidCallback onLeave;

  const MultiplayerResultModal({
    super.key,
    required this.room,
    required this.targetPerfume,
    required this.onLeave,
  });

  static Future<void> show(
    BuildContext context, {
    required MultiplayerRoom room,
    required PerfumeModel targetPerfume,
    required VoidCallback onLeave,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => MultiplayerResultModal(
        room: room,
        targetPerfume: targetPerfume,
        onLeave: onLeave,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final multiplayer = context.watch<MultiplayerProvider>();
    final myId = multiplayer.myPlayerId;
    final me = room.players[myId];
    final opp = room.opponentOf(myId);
    final sc = context.sc;

    final isWon = room.winnerId == myId;
    final isDraw = room.winnerId == 'DRAW';

    final Color titleColor;
    final String headline;
    final IconData headlineIcon;

    if (isWon) {
      titleColor = sc.exactMatch;
      headline = 'VICTORY';
      headlineIcon = Icons.emoji_events_outlined;
    } else if (isDraw) {
      titleColor = sc.accent;
      headline = 'STALEMATE (DRAW)';
      headlineIcon = Icons.handshake_outlined;
    } else {
      titleColor = sc.errorRed;
      headline = 'DEFEAT';
      headlineIcon = Icons.close;
    }

    final reasonSubtitle = _getReasonSubtitle(room.winReason, isWon);
    final eloDelta = multiplayer.lastProcessedEloDelta ?? 0;
    final currentElo = StorageService.instance.getUserStats().eloRating;
    final prevElo = currentElo - eloDelta;
    final rank = RankService.getRank(currentElo);

    return Dialog(
      backgroundColor: sc.cardSurface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: titleColor.withValues(alpha: 0.6),
          width: 1.5,
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Outcome Headline with Vector Icon
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(headlineIcon, size: 24, color: titleColor),
                  const SizedBox(width: 8),
                  Text(
                    headline,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2.0,
                      color: titleColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                reasonSubtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: sc.mutedText,
                ),
              ),

              const SizedBox(height: 16),

              // 2. ELO Rating Adjustment Card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: sc.surfaceSecondary,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: sc.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(rank.icon, size: 20, color: rank.color),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              rank.title,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: rank.color,
                              ),
                            ),
                            Text(
                              '$prevElo → $currentElo ELO',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: sc.primaryText,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: (eloDelta >= 0 ? sc.exactMatch : sc.errorRed)
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        eloDelta >= 0 ? '+$eloDelta ELO' : '$eloDelta ELO',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: eloDelta >= 0 ? sc.exactMatch : sc.errorRed,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 3. Unblurred Target Bottle & Details
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: sc.cardSurface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: sc.border),
                ),
                child: Row(
                  children: [
                    BottleImageWidget(
                      perfume: targetPerfume,
                      blurSigma: 0.0,
                      width: 65,
                      height: 85,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'THE MYSTERY TARGET',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                              color: sc.accent,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            targetPerfume.name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: sc.primaryText,
                            ),
                          ),
                          Text(
                            '${targetPerfume.brand} • ${targetPerfume.year}',
                            style: TextStyle(
                              fontSize: 12,
                              color: sc.mutedText,
                            ),
                          ),
                          if (targetPerfume.perfumer.isNotEmpty && targetPerfume.perfumer != 'N/A') ...[
                            const SizedBox(height: 2),
                            Text(
                              'Perfumer: ${targetPerfume.perfumer}',
                              style: TextStyle(
                                fontSize: 10,
                                fontStyle: FontStyle.italic,
                                color: sc.mutedText,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // 4. Side-by-Side Guess Reveal Table
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'SIDE-BY-SIDE GUESS REVEAL',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                    color: sc.primaryText,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              _buildSideBySideTable(sc, me, opp),

              const SizedBox(height: 22),

              // 5. Action Buttons (Rematch + Leave)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onLeave,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: sc.secondaryText,
                        side: BorderSide(color: sc.border),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('LEAVE DUEL'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: me?.wantsRematch == true
                          ? null
                          : () async {
                              await multiplayer.requestRematch();
                            },
                      icon: Icon(Icons.refresh, size: 16, color: sc.ctaForeground),
                      label: me?.wantsRematch == true
                          ? const Text(
                              'WAITING...',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                            )
                          : const Text(
                              'REMATCH',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: sc.ctaBackground,
                        foregroundColor: sc.ctaForeground,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getReasonSubtitle(String? reason, bool isWon) {
    switch (reason) {
      case 'SOLVED_FIRST':
        return isWon
            ? 'You deduced the secret perfume first!'
            : 'Opponent solved the fragrance before you!';
      case 'CLOSEST_ON_TIMEOUT':
        return isWon
            ? 'Master clock expired • You had higher olfactory closeness!'
            : 'Master clock expired • Opponent was closer to the target!';
      case 'CLOSEST_AFTER_EXHAUSTION':
        return isWon
            ? 'Both players used 6 turns • Won on closest guess!'
            : 'Both players used 6 turns • Opponent scored closer!';
      case 'OPPONENT_FORFEIT':
        return 'Opponent departed the duel session.';
      case 'DRAW':
        return 'Exact tie on turns and closeness points!';
      default:
        return '1v1 Duel Concluded';
    }
  }

  Widget _buildSideBySideTable(
    ScentleThemeColors sc,
    MultiplayerPlayerState? me,
    MultiplayerPlayerState? opp,
  ) {
    final repo = PerfumeRepository.instance;
    final myIds = me?.guessedPerfumeIds ?? [];
    final oppIds = opp?.guessedPerfumeIds ?? [];
    final maxTurns = [myIds.length, oppIds.length, me?.turnCount ?? 0, opp?.turnCount ?? 0].reduce((a, b) => a > b ? a : b);

    if (maxTurns == 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'No guesses submitted during this duel.',
          style: TextStyle(fontSize: 11, color: sc.mutedText),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: sc.cardSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: sc.border),
      ),
      child: Column(
        children: [
          // Header row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: sc.surfaceSecondary,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(9)),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 30,
                  child: Text(
                    'T#',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: sc.mutedText),
                  ),
                ),
                Expanded(
                  child: Text(
                    me?.nickname ?? 'You',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: sc.primaryText),
                  ),
                ),
                Expanded(
                  child: Text(
                    opp?.nickname ?? 'Opponent',
                    textAlign: TextAlign.end,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: sc.mutedText),
                  ),
                ),
              ],
            ),
          ),
          // Rows
          ...List.generate(maxTurns, (index) {
            final myPerfume = index < myIds.length ? repo.getById(myIds[index]) : null;
            final oppPerfume = index < oppIds.length ? repo.getById(oppIds[index]) : null;

            final myLabel = myPerfume != null ? myPerfume.name : (index < (me?.turnCount ?? 0) ? 'Skipped' : '—');
            final oppLabel = oppPerfume != null ? oppPerfume.name : (index < (opp?.turnCount ?? 0) ? 'Skipped' : '—');

            final isMyCorrect = myPerfume?.id == targetPerfume.id;
            final isOppCorrect = oppPerfume?.id == targetPerfume.id;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: sc.border.withValues(alpha: 0.5)),
                ),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 30,
                    child: Text(
                      '#${index + 1}',
                      style: TextStyle(fontSize: 10, color: sc.mutedText),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      myLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isMyCorrect ? FontWeight.bold : FontWeight.normal,
                        color: isMyCorrect ? sc.exactMatch : sc.primaryText,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      oppLabel,
                      textAlign: TextAlign.end,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isOppCorrect ? FontWeight.bold : FontWeight.normal,
                        color: isOppCorrect ? sc.exactMatch : sc.mutedText,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
