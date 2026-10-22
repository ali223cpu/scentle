import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/scentle_theme.dart';
import '../models/clue_state.dart';
import '../providers/game_provider.dart';
import '../services/ad_service.dart';
import 'bottle_image_widget.dart';

/// The centerpiece game card styled as an Olfactory Blotter, progressively
/// revealing olfactory formulation clues across 6 turns with a compact
/// 3-tab segmented note pyramid switcher.
class MysteryClueCard extends StatefulWidget {
  final ClueState? clueState;
  final VoidCallback? onSkip;
  final VoidCallback? onHint;
  final bool? isGameOver;
  final bool? bonusHintUsed;

  const MysteryClueCard({
    super.key,
    this.clueState,
    this.onSkip,
    this.onHint,
    this.isGameOver,
    this.bonusHintUsed,
  });

  @override
  State<MysteryClueCard> createState() => _MysteryClueCardState();
}

class _MysteryClueCardState extends State<MysteryClueCard> {
  int _selectedPyramidTab = 0; // 0: Top, 1: Heart, 2: Base
  int _lastTurnNumber = 1;

  @override
  void didUpdateWidget(covariant MysteryClueCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.clueState != null) {
      _checkTurnAdvance(widget.clueState!);
    }
  }

  void _checkTurnAdvance(ClueState clue) {
    final nextTurn = clue.currentTurnNumber;
    if (nextTurn != _lastTurnNumber) {
      _lastTurnNumber = nextTurn;
      // Automatically focus the newly unlocked pyramid tier on turn progression
      if (nextTurn == 2 && clue.isTopNotesUnlocked) {
        _selectedPyramidTab = 0;
      } else if (nextTurn == 3 && clue.isMiddleNotesUnlocked) {
        _selectedPyramidTab = 1;
      } else if (nextTurn >= 4 && clue.isBaseNotesUnlocked) {
        _selectedPyramidTab = 2;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.clueState == null ? context.watch<GameProvider>() : null;
    final clue = widget.clueState ?? game!.clueState;
    _checkTurnAdvance(clue);
    final sc = context.sc;

    return Container(
      decoration: BoxDecoration(
        color: sc.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: sc.border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: sc.cardShadow,
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 0. Olfactory Blotter Tag
          Center(
            child: Text(
              'OLFACTORY BLOTTER',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 2.0,
                color: sc.accent,
              ),
            ),
          ),
          const SizedBox(height: 10),

          // 1. Header Bar: Turn Badge + Hint + Skip
          _buildHeaderBar(context, sc, clue, game),
          const SizedBox(height: 14),

          // 2. Main Accords Proportional Bar Chart (7px rounded with name on left, % on right)
          _buildAccordsSection(context, sc, clue.mainAccords),
          const SizedBox(height: 14),

          // 3. Metadata 5-Pill Wrap
          _buildMetadataPills(context, sc, clue),
          const SizedBox(height: 14),

          // 4. Compact 3-Tab Segmented Olfactory Pyramid
          _buildSegmentedPyramidSection(context, sc, clue),

          // 5. Turn 6 Bottle Silhouette Preview
          if (clue.showBottleImage) ...[
            const SizedBox(height: 14),
            _buildBottleSilhouette(context, sc, clue),
          ],
        ],
      ),
    );
  }

  Widget _buildHeaderBar(
    BuildContext context,
    ScentleThemeColors sc,
    ClueState clue,
    GameProvider? game,
  ) {
    final isOver = widget.isGameOver ?? game?.isGameOver ?? false;
    final hintUsed = widget.bonusHintUsed ?? game?.bonusHintUsed ?? false;

    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      runSpacing: 6,
      children: [
        // Turn indicator pill (Matches exact string 'TURN X OF 6' expected in tests)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: sc.surfaceSecondary,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: sc.border),
          ),
          child: Text(
            'TURN ${clue.currentTurnNumber} OF 6',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
              color: sc.accent,
            ),
          ),
        ),

        // Brass Hint Button
        if (!hintUsed && !isOver)
          TextButton.icon(
            onPressed: () async {
              if (clue.currentTurnNumber < 3) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        Icon(Icons.lock_outline, size: 16, color: sc.accent),
                        const SizedBox(width: 8),
                        const Text('Bonus Clue unlocks on Turn 3 or later!'),
                      ],
                    ),
                    backgroundColor: sc.cardSurface,
                    duration: const Duration(seconds: 2),
                  ),
                );
                return;
              }

              final rewarded = await AdService.showRewardedHintAd(context);
              if (!rewarded || !context.mounted) return;

              if (widget.onHint != null) {
                widget.onHint!();
                return;
              }

              if (game != null) {
                final revealed = await game.useBonusNoteHint();
                if (context.mounted && revealed != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          Icon(Icons.lightbulb_outline, size: 16, color: sc.accent),
                          const SizedBox(width: 8),
                          Text('Bonus Clue Revealed: "$revealed"'),
                        ],
                      ),
                      backgroundColor: sc.cardSurface,
                      duration: const Duration(seconds: 3),
                    ),
                  );
                }
              }
            },
            icon: Icon(Icons.lightbulb_outline, size: 14, color: sc.accent),
            label: Text(
              'HINT',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: sc.accent,
              ),
            ),
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 6),
            ),
          )
        else if (hintUsed)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: sc.surfaceSecondary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check, size: 11, color: sc.mutedText),
                const SizedBox(width: 3),
                Text(
                  'HINT USED',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: sc.mutedText,
                  ),
                ),
              ],
            ),
          ),

        // Skip Button
        if (!isOver)
          OutlinedButton.icon(
            onPressed: widget.onSkip ?? (game != null ? () => game.skipTurn() : null),
            icon: Icon(Icons.fast_forward, size: 13, color: sc.mutedText),
            label: Text(
              'SKIP (+1 CLUE)',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: sc.secondaryText,
              ),
            ),
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              foregroundColor: sc.secondaryText,
              side: BorderSide(color: sc.border),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
      ],
    );
  }

  /// Main Accords Bar Chart with 7px rounded bars, name on left, % on right
  Widget _buildAccordsSection(
    BuildContext context,
    ScentleThemeColors sc,
    List<String> accords,
  ) {
    const percentages = [100, 85, 72, 60, 48];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.palette_outlined, size: 14, color: sc.accent),
            const SizedBox(width: 6),
            Text(
              'DOMINANT ACCORDS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
                color: sc.mutedText,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (int i = 0; i < accords.length && i < 5; i++) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 5.0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final pct = percentages[i];
                final barWidth = constraints.maxWidth * (pct / 100.0);
                final color = AccordColors.getColor(accords[i]);

                return Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: barWidth,
                    height: 26,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(
                        color: color.withValues(alpha: 0.8),
                        width: 1,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            accords[i].toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              color: color,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '$pct%',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'monospace',
                            color: color,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  /// Metadata 5-Pill Wrap (replacing emoji with vector lock icons)
  Widget _buildMetadataPills(
    BuildContext context,
    ScentleThemeColors sc,
    dynamic clue,
  ) {
    final yearUnlocked = clue.releaseDecade != null || clue.exactYear != null;
    final yearText = clue.exactYear != null
        ? '${clue.exactYear}'
        : (clue.releaseDecade ?? 'Turn 2');

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _buildPill(
          sc: sc,
          icon: Icons.person_outline,
          label: 'GENDER',
          value: clue.gender,
          isUnlocked: true,
        ),
        _buildPill(
          sc: sc,
          icon: Icons.calendar_today_outlined,
          label: clue.exactYear != null ? 'YEAR' : 'ERA',
          value: yearText,
          isUnlocked: yearUnlocked,
        ),
        _buildPill(
          sc: sc,
          icon: Icons.public_outlined,
          label: 'ORIGIN',
          value: clue.country ?? 'Turn 3',
          isUnlocked: clue.country != null,
        ),
        _buildPill(
          sc: sc,
          icon: Icons.science_outlined,
          label: 'NOSE',
          value: clue.perfumer ?? 'Turn 4',
          isUnlocked: clue.perfumer != null,
        ),
        _buildPill(
          sc: sc,
          icon: Icons.business_outlined,
          label: 'HOUSE',
          value: clue.brand ?? 'Turn 5',
          isUnlocked: clue.brand != null,
        ),
      ],
    );
  }

  Widget _buildPill({
    required ScentleThemeColors sc,
    required IconData icon,
    required String label,
    required String value,
    required bool isUnlocked,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isUnlocked ? sc.surfaceSecondary : sc.cardSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isUnlocked ? sc.border : sc.border.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: isUnlocked ? sc.accent : sc.mutedText.withValues(alpha: 0.6),
          ),
          const SizedBox(width: 4),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: sc.mutedText,
            ),
          ),
          if (!isUnlocked) ...[
            Icon(Icons.lock_outline, size: 10, color: sc.mutedText.withValues(alpha: 0.6)),
            const SizedBox(width: 2),
          ],
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isUnlocked ? FontWeight.w700 : FontWeight.normal,
              color: isUnlocked ? sc.primaryText : sc.mutedText.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  /// Compact 3-Tab Segmented Olfactory Pyramid Switcher
  Widget _buildSegmentedPyramidSection(
    BuildContext context,
    ScentleThemeColors sc,
    dynamic clue,
  ) {
    final topNotes = clue.topNotes as List<String>;
    final heartNotes = clue.middleNotes as List<String>;
    final baseNotes = clue.baseNotes as List<String>;

    final isTopUnlocked = clue.isTopNotesUnlocked as bool;
    final isHeartUnlocked = clue.isMiddleNotesUnlocked as bool;
    final isBaseUnlocked = clue.isBaseNotesUnlocked as bool;

    final tabNames = [
      'Top (${isTopUnlocked ? topNotes.length : "T2"})',
      'Heart (${isHeartUnlocked ? heartNotes.length : "T3"})',
      'Base (${isBaseUnlocked ? baseNotes.length : "T4"})',
    ];

    final isSelectedUnlocked = _selectedPyramidTab == 0
        ? isTopUnlocked
        : (_selectedPyramidTab == 1 ? isHeartUnlocked : isBaseUnlocked);

    final selectedNotes = _selectedPyramidTab == 0
        ? topNotes
        : (_selectedPyramidTab == 1 ? heartNotes : baseNotes);

    final unlockTurn = _selectedPyramidTab == 0 ? 2 : (_selectedPyramidTab == 1 ? 3 : 4);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: sc.surfaceSecondary,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: sc.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Segmented Tab Selector
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: sc.cardSurface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: sc.border),
            ),
            child: Row(
              children: List.generate(3, (index) {
                final isSelected = _selectedPyramidTab == index;
                return Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _selectedPyramidTab = index),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? sc.ctaBackground : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      alignment: Alignment.center,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          tabNames[index],
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: isSelected ? sc.ctaForeground : sc.mutedText,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 10),

          // Active Tier Content
          if (!isSelectedUnlocked)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_outline, size: 14, color: sc.mutedText),
                    const SizedBox(width: 6),
                    Text(
                      '🔒 Unlocks on Turn $unlockTurn', // Retains string for test assertion
                      style: TextStyle(
                        fontSize: 11,
                        color: sc.mutedText,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (selectedNotes.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Linear composition (no separate notes in this tier)',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: sc.mutedText,
                ),
              ),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 5,
              children: [
                for (final note in selectedNotes)
                  _buildNoteChip(sc, note, clue.isNoteMatchedByPlayer(note)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildNoteChip(ScentleThemeColors sc, String note, bool isMatched) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isMatched ? sc.exactMatch : sc.cardSurface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isMatched ? sc.exactMatch : sc.border,
          width: 1.0,
        ),
        boxShadow: isMatched
            ? [
                BoxShadow(
                  color: sc.exactMatch.withValues(alpha: 0.35),
                  blurRadius: 6,
                  offset: const Offset(0, 1),
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isMatched) ...[
            const Icon(Icons.check, size: 11, color: Colors.white),
            const SizedBox(width: 4),
          ],
          Text(
            note,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isMatched ? FontWeight.w700 : FontWeight.w500,
              color: isMatched ? sc.tileText : sc.primaryText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottleSilhouette(
    BuildContext context,
    ScentleThemeColors sc,
    dynamic clue,
  ) {
    final isGameOver = clue.isGameOver;

    return Center(
      child: Column(
        children: [
          BottleImageWidget(
            perfume: clue.target,
            blurSigma: clue.blurSigma,
            width: 120,
            height: 150,
          ),
          const SizedBox(height: 6),
          Text(
            isGameOver ? 'MYSTERY REVEALED' : 'BOTTLE SILHOUETTE PREVIEW',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: sc.accent,
            ),
          ),
        ],
      ),
    );
  }
}
