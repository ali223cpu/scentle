import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/scentle_theme.dart';
import '../models/guess_result.dart';
import '../models/turn_entry.dart';
import '../providers/game_provider.dart';

/// Renders chronological session turns in reverse (most recent at top)
/// with solid-fill editorial comparison tiles (Sage, Terracotta, Stone).
class GuessHistoryList extends StatelessWidget {
  final List<TurnEntry>? entries;

  const GuessHistoryList({
    super.key,
    this.entries,
  });

  @override
  Widget build(BuildContext context) {
    final list = (entries ?? context.watch<GameProvider>().turnEntries).reversed.toList();
    final sc = context.sc;

    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24.0),
          child: Text(
            'Begin your olfactory deduction. Enter a fragrance above.',
            style: TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: sc.mutedText,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final entry = list[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: entry.isSkip
              ? _buildSkippedCard(sc, entry)
              : _buildGuessCard(sc, entry.guessResult!, entry.turnNumber),
        );
      },
    );
  }

  Widget _buildSkippedCard(ScentleThemeColors sc, TurnEntry entry) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: sc.surfaceSecondary,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: sc.border),
      ),
      child: Row(
        children: [
          Icon(Icons.fast_forward, size: 16, color: sc.mutedText),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'Turn ${entry.turnNumber} — Skipped (+1 Clue Unlocked)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: sc.mutedText,
                fontStyle: FontStyle.italic,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuessCard(
    ScentleThemeColors sc,
    GuessResult result,
    int turnNumber,
  ) {
    final p = result.guessedPerfume;

    return Container(
      decoration: BoxDecoration(
        color: sc.cardSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: result.isCorrect
              ? sc.exactMatch
              : (result.isFlankerMatch ? sc.closeMatch : sc.border),
          width: result.isCorrect || result.isFlankerMatch ? 1.5 : 1.0,
        ),
        boxShadow: [
          if (result.isCorrect)
            BoxShadow(
              color: sc.exactMatch.withValues(alpha: 0.25),
              blurRadius: 10,
              offset: const Offset(0, 3),
            )
          else if (result.isFlankerMatch)
            BoxShadow(
              color: sc.closeMatch.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Turn number badge + Brand & Perfume Name + Year
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: sc.surfaceSecondary,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: sc.border),
                ),
                child: Text(
                  '#$turnNumber',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: sc.primaryText,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: RichText(
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '${p.brand} ',
                        style: TextStyle(
                          color: sc.accent,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      TextSpan(
                        text: p.name,
                        style: TextStyle(
                          color: sc.primaryText,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      if (p.year > 0)
                        TextSpan(
                          text: ' (${p.year})',
                          style: TextStyle(
                            color: sc.mutedText,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Flanker Match Alert Banner (Terracotta alert with vector icon)
          if (result.isFlankerMatch) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: sc.closeMatchBadgeFill,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: sc.closeMatch.withValues(alpha: 0.7)),
              ),
              child: Row(
                children: [
                  Icon(Icons.whatshot_outlined, size: 15, color: sc.closeMatchText),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'SO CLOSE! Sister flanker from the same line — check concentration or year!',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: sc.closeMatchText,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 10),

          // 4-Tile Attribute Comparison Strip (Solid fills)
          Row(
            children: [
              Expanded(
                child: _buildComparisonTile(
                  sc: sc,
                  title: 'HOUSE',
                  value: p.brand,
                  status: result.brandStatus,
                  subtitle: result.brandStatus == MatchStatus.close
                      ? 'Origin: ${p.country}'
                      : null,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildComparisonTile(
                  sc: sc,
                  title: 'YEAR',
                  value: p.year > 0 ? '${p.year}' : '?',
                  status: result.yearStatus,
                  badgeIcon: _getYearDirectionIcon(result.yearDirection),
                  subtitle: _getYearDirectionLabel(result.yearDirection),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildComparisonTile(
                  sc: sc,
                  title: 'ACCORDS',
                  value: '${result.sharedAccords.length} Shared',
                  status: result.accordsStatus,
                  subtitle: result.topAccordExactMatch ? 'Top Accord' : null,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildComparisonTile(
                  sc: sc,
                  title: 'NOTES',
                  value: '${result.sharedNotes.length} Matched',
                  status: result.notesStatus,
                ),
              ),
            ],
          ),

          // Shared Notes & Accords Discovery Pills Wrap
          if (result.sharedNotes.isNotEmpty || result.sharedAccords.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 5,
              runSpacing: 4,
              children: [
                for (final accord in result.sharedAccords)
                  _buildDiscoveryPill(
                    sc: sc,
                    label: accord.toUpperCase(),
                    isAccord: true,
                  ),
                for (final note in result.sharedNotes)
                  _buildDiscoveryPill(
                    sc: sc,
                    label: note,
                    isAccord: false,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildComparisonTile({
    required ScentleThemeColors sc,
    required String title,
    required String value,
    required MatchStatus status,
    Widget? badgeIcon,
    String? subtitle,
  }) {
    final bgColor = _getStatusColor(sc, status);
    final isMiss = status == MatchStatus.miss;
    final textColor = isMiss ? sc.missText : sc.tileText;
    final titleColor = isMiss ? sc.missText.withValues(alpha: 0.8) : Colors.white.withValues(alpha: 0.85);

    return Container(
      constraints: const BoxConstraints(minHeight: 60),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: isMiss ? Border.all(color: sc.border) : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: titleColor,
            ),
            maxLines: 1,
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              if (badgeIcon != null) ...[
                const SizedBox(width: 2),
                badgeIcon,
              ],
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 1),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 8,
                color: isMiss ? sc.missText : Colors.white.withValues(alpha: 0.85),
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDiscoveryPill({
    required ScentleThemeColors sc,
    required String label,
    required bool isAccord,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isAccord ? sc.accentBadgeFill : sc.exactMatchBadgeFill,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isAccord
              ? sc.accent.withValues(alpha: 0.5)
              : sc.exactMatch.withValues(alpha: 0.5),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isAccord ? Icons.palette_outlined : Icons.eco_outlined,
            size: 9,
            color: isAccord ? sc.accent : sc.exactMatch,
          ),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: isAccord ? sc.accent : sc.exactMatch,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(ScentleThemeColors sc, MatchStatus status) {
    switch (status) {
      case MatchStatus.exact:
        return sc.exactMatch;
      case MatchStatus.close:
        return sc.closeMatch;
      case MatchStatus.miss:
        return sc.missTile;
    }
  }

  Widget? _getYearDirectionIcon(YearDirection direction) {
    switch (direction) {
      case YearDirection.newer:
        return const Icon(Icons.arrow_upward, size: 11, color: Colors.white);
      case YearDirection.older:
        return const Icon(Icons.arrow_downward, size: 11, color: Colors.white);
      case YearDirection.equal:
        return const Icon(Icons.check, size: 11, color: Colors.white);
    }
  }

  String? _getYearDirectionLabel(YearDirection direction) {
    switch (direction) {
      case YearDirection.newer:
        return 'Target is newer';
      case YearDirection.older:
        return 'Target is older';
      case YearDirection.equal:
        return 'Exact Match';
    }
  }
}
