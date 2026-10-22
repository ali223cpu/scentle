import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/scentle_theme.dart';
import '../providers/game_provider.dart';
import '../widgets/game_over_modal.dart';
import '../widgets/guess_history_list.dart';
import '../widgets/how_to_play_modal.dart';
import '../widgets/mystery_clue_card.dart';
import '../widgets/perfume_search_bar.dart';
import '../widgets/stats_modal.dart';

/// Active gameplay arena hosting the MysteryClueCard, 6-dot turn indicator,
/// autocomplete search, and GuessHistoryList for Daily and Unlimited modes.
class GameScreen extends StatefulWidget {
  final GameMode mode;

  const GameScreen({
    super.key,
    required this.mode,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  bool _modalShownForCurrentSession = false;

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameProvider>();
    final sc = context.sc;

    // Trigger GameOverModal automatically once upon game completion
    if (game.isGameOver && !_modalShownForCurrentSession) {
      _modalShownForCurrentSession = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          GameOverModal.show(context);
        }
      });
    } else if (!game.isGameOver && _modalShownForCurrentSession) {
      _modalShownForCurrentSession = false;
    }

    final turnsUsed = game.turnEntries.length;
    final currentTurn = (turnsUsed + 1).clamp(1, 6);

    final String modeTitle = widget.mode == GameMode.daily
        ? 'DAILY N° ${game.puzzleNumber} • TURN $currentTurn OF 6'
        : 'ATELIER UNLIMITED • TURN $currentTurn OF 6';

    return Scaffold(
      backgroundColor: sc.scaffoldBg,
      appBar: AppBar(
        backgroundColor: sc.scaffoldBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, size: 18, color: sc.primaryText),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                modeTitle,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: sc.primaryText,
                ),
              ),
            ),
            const SizedBox(height: 6),
            // 6-Dot Visual Turn Indicator Row
            _buildTurnDotsRow(sc, turnsUsed, currentTurn, game.isGameOver),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.help_outline, color: sc.mutedText, size: 20),
            tooltip: 'How to Play',
            onPressed: () => HowToPlayModal.show(context),
          ),
          IconButton(
            icon: Icon(Icons.bar_chart_outlined, color: sc.accent, size: 20),
            tooltip: 'Career Stats',
            onPressed: () => StatsModal.show(context),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Progressive Mystery Clue Card (Olfactory Blotter)
              const MysteryClueCard(),

              const SizedBox(height: 14),

              // 2. Autocomplete Search Bar or Game-Over Controls
              PerfumeSearchBar(
                onOpenGameOverModal: () => GameOverModal.show(context),
              ),

              const SizedBox(height: 16),

              // 3. Chronological Guess History (Newest at top)
              const GuessHistoryList(),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  /// 6-dot visual turn indicator row
  /// Terracotta amber for used turns, scaled 1.2x espresso black for current turn,
  /// soft border stone for remaining turns.
  Widget _buildTurnDotsRow(
    ScentleThemeColors sc,
    int turnsUsed,
    int currentTurn,
    bool isGameOver,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(6, (index) {
        final dotTurn = index + 1;
        final isUsed = dotTurn <= turnsUsed;
        final isCurrent = dotTurn == currentTurn && !isGameOver;

        Color dotColor;
        double size = 8.0;

        if (isUsed) {
          dotColor = sc.closeMatch; // Terracotta amber for used
        } else if (isCurrent) {
          dotColor = sc.primaryText; // Espresso ink for active
          size = 10.0;
        } else {
          dotColor = sc.border; // Neutral stone for remaining
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
            border: isCurrent
                ? Border.all(color: sc.accent, width: 1.5)
                : null,
          ),
        );
      }),
    );
  }
}
