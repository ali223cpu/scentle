import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/scentle_theme.dart';
import '../providers/multiplayer_provider.dart';
import '../widgets/guess_history_list.dart';
import '../widgets/live_opponent_hud.dart';
import '../widgets/multiplayer_result_modal.dart';
import '../widgets/mystery_clue_card.dart';
import '../widgets/perfume_search_bar.dart';

/// Real-time 1v1 multiplayer game screen orchestrating the live duel loop,
/// opponent HUD, progressive clue card, search bar, and post-duel modal.
class MultiplayerGameScreen extends StatefulWidget {
  const MultiplayerGameScreen({super.key});

  @override
  State<MultiplayerGameScreen> createState() => _MultiplayerGameScreenState();
}

class _MultiplayerGameScreenState extends State<MultiplayerGameScreen> {
  bool _isModalShowing = false;

  @override
  Widget build(BuildContext context) {
    final multiplayer = context.watch<MultiplayerProvider>();
    final room = multiplayer.currentRoom;
    final target = multiplayer.targetPerfume;
    final sc = context.sc;

    if (room == null || target == null) {
      return Scaffold(
        backgroundColor: sc.scaffoldBg,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: sc.accent),
              const SizedBox(height: 16),
              Text(
                'Connecting to olfactory duel...',
                style: TextStyle(color: sc.mutedText),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('BACK TO LOBBY', style: TextStyle(color: sc.accent)),
              ),
            ],
          ),
        ),
      );
    }

    // Auto-trigger Result Modal when match finishes
    if (room.status == 'finished' && !_isModalShowing) {
      _isModalShowing = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        MultiplayerResultModal.show(
          context,
          room: room,
          targetPerfume: target,
          onLeave: () async {
            final nav = Navigator.of(context);
            nav.pop(); // Dismiss dialog
            _isModalShowing = false;
            await multiplayer.leaveRoom();
            if (mounted) nav.pop(); // Back to lobby
          },
        ).then((_) {
          _isModalShowing = false;
        });
      });
    } else if (room.status == 'playing' && _isModalShowing) {
      // Rematch round triggered while modal was open
      Navigator.of(context, rootNavigator: true).pop();
      _isModalShowing = false;
    }

    final me = multiplayer.myState;
    final hasExhaustedTurns = me?.exhaustedTurns == true || multiplayer.turnEntries.length >= 6;
    final isSolved = me?.solved == true;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeaveDuel(context, sc, multiplayer);
      },
      child: Scaffold(
        backgroundColor: sc.scaffoldBg,
        appBar: AppBar(
          backgroundColor: sc.scaffoldBg,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: sc.primaryText),
            onPressed: () => _confirmLeaveDuel(context, sc, multiplayer),
          ),
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'ROOM: ',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: sc.mutedText,
                ),
              ),
              Text(
                room.roomCode,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0,
                  color: sc.accent,
                ),
              ),
            ],
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: Icon(Icons.exit_to_app, color: sc.mutedText),
              tooltip: 'Leave Duel',
              onPressed: () => _confirmLeaveDuel(context, sc, multiplayer),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              // 1. Pinned Dark Espresso Opponent HUD Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
                child: LiveOpponentHudWidget(
                  myState: multiplayer.myState,
                  opponentState: multiplayer.opponentState,
                  remainingSeconds: multiplayer.remainingSeconds,
                ),
              ),

              // 2. Main Scrollable Warm Alabaster Arena
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Progressive Olfactory Clue Card
                      MysteryClueCard(
                        clueState: multiplayer.clueState,
                        onSkip: (hasExhaustedTurns || isSolved) ? null : () => multiplayer.skipTurn(),
                        onHint: multiplayer.bonusNoteRevealed ? null : () => multiplayer.useBonusNoteHint(),
                        isGameOver: room.status == 'finished',
                        bonusHintUsed: multiplayer.bonusNoteRevealed,
                      ),

                      const SizedBox(height: 12),

                      // Turn Input or Waiting Banner
                      if (isSolved)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: sc.exactMatchBadgeFill,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: sc.exactMatch),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle_outline, color: sc.exactMatch, size: 18),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  'Target Solved! Awaiting opponent...',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: sc.exactMatch,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (hasExhaustedTurns)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: sc.cardSurface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: sc.border),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: sc.accent,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Text(
                                  'All 6 turns used! Watching opponent\'s final turns...',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: sc.mutedText,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        PerfumeSearchBar(
                          excludedPerfumeIds: multiplayer.guessedPerfumeIds,
                          onSelected: (perfume) => multiplayer.submitGuess(perfume),
                          isGameOver: false,
                        ),

                      const SizedBox(height: 14),

                      // Turn Guess History
                      GuessHistoryList(entries: multiplayer.turnEntries),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmLeaveDuel(
    BuildContext context,
    ScentleThemeColors sc,
    MultiplayerProvider multiplayer,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: sc.cardSurface,
        title: Text(
          'Forfeit Duel?',
          style: TextStyle(color: sc.primaryText, fontSize: 16),
        ),
        content: Text(
          'Leaving an active 1v1 duel will forfeit the match and count as a loss toward your ELO rating.',
          style: TextStyle(color: sc.mutedText, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('STAY', style: TextStyle(color: sc.mutedText)),
          ),
          ElevatedButton(
            onPressed: () async {
              final nav = Navigator.of(context);
              Navigator.of(ctx).pop(); // dismiss dialog
              await multiplayer.leaveRoom();
              if (mounted) nav.pop(); // pop screen
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: sc.errorRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('FORFEIT & LEAVE'),
          ),
        ],
      ),
    );
  }
}
