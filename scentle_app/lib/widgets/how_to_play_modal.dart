import 'package:flutter/material.dart';
import '../core/theme/scentle_theme.dart';

/// Modal visually explaining Scentle gameplay, progressive clue unlocks,
/// comparison tile colors, and flanker detection.
class HowToPlayModal extends StatelessWidget {
  const HowToPlayModal({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => const HowToPlayModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sc = context.sc;

    return Dialog(
      backgroundColor: sc.cardSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: sc.border, width: 1.2),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'HOW TO PLAY',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                    color: sc.primaryText,
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
            const SizedBox(height: 14),

            Text(
              'Deduce the secret luxury fragrance in 6 turns. Each turn unlocks clues from the Olfactory Pyramid to guide your next guess.',
              style: TextStyle(
                fontSize: 13,
                color: sc.primaryText,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),

            // Color Rules
            _buildSectionHeader(sc, 'ATTRIBUTE COMPARISON COLORS'),
            const SizedBox(height: 8),
            _buildColorRow(
              sc: sc,
              color: sc.exactMatch,
              label: 'EXACT MATCH',
              desc: 'Identical Brand, Exact Year, or Top Accord / high note match.',
            ),
            const SizedBox(height: 6),
            _buildColorRow(
              sc: sc,
              color: sc.closeMatch,
              label: 'CLOSE MATCH',
              desc: 'Same origin country, release year within ±5 years, or shared notes.',
            ),
            const SizedBox(height: 6),
            _buildColorRow(
              sc: sc,
              color: sc.missTile,
              textColor: sc.missText,
              label: 'MISS',
              desc: 'Attribute does not match.',
            ),
            const SizedBox(height: 16),

            // Directional Year Arrows
            _buildSectionHeader(sc, 'RELEASE YEAR ARROWS'),
            const SizedBox(height: 8),
            _buildDirectionRow(
              sc: sc,
              icon: Icons.arrow_upward,
              label: '↑ Arrow',
              desc: 'The secret perfume was released NEWER than your guess.',
            ),
            const SizedBox(height: 6),
            _buildDirectionRow(
              sc: sc,
              icon: Icons.arrow_downward,
              label: '↓ Arrow',
              desc: 'The secret perfume was released OLDER than your guess.',
            ),
            const SizedBox(height: 16),

            // Flanker Alert Banner
            _buildSectionHeader(sc, 'FLANKER MATCH ALERT'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: sc.closeMatchBadgeFill,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: sc.closeMatch.withValues(alpha: 0.8)),
              ),
              child: Row(
                children: [
                  Icon(Icons.whatshot_outlined, size: 16, color: sc.closeMatchText),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'If you guess a sister flanker (e.g. Sauvage EDP when the mystery target is Sauvage EDT), the card highlights with a glowing Flanker alert!',
                      style: TextStyle(
                        fontSize: 11,
                        color: sc.closeMatchText,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Progressive Clue Ladder
            _buildSectionHeader(sc, 'PROGRESSIVE CLUE LADDER'),
            const SizedBox(height: 8),
            _buildClueLadderItem(sc, 'Turn 1', 'Main Accords & Gender (Always unlocked)'),
            _buildClueLadderItem(sc, 'Turn 2', 'Top Notes & Release Era / Decade'),
            _buildClueLadderItem(sc, 'Turn 3', 'Heart / Middle Notes & Origin Country'),
            _buildClueLadderItem(sc, 'Turn 4', 'Base Notes & Primary Perfumer ("Nose")'),
            _buildClueLadderItem(sc, 'Turn 5', 'House / Brand Name & Exact Year'),
            _buildClueLadderItem(sc, 'Turn 6', 'Blurred Bottle Silhouette Preview'),

            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 42,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: sc.ctaBackground,
                  foregroundColor: sc.ctaForeground,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'UNDERSTOOD',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(ScentleThemeColors sc, String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.0,
        color: sc.accent,
      ),
    );
  }

  Widget _buildColorRow({
    required ScentleThemeColors sc,
    required Color color,
    Color? textColor,
    required String label,
    required String desc,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 14,
          height: 14,
          margin: const EdgeInsets.only(top: 2),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: sc.border),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$label: ',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: textColor ?? color,
                  ),
                ),
                TextSpan(
                  text: desc,
                  style: TextStyle(
                    fontSize: 11,
                    color: sc.mutedText,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDirectionRow({
    required ScentleThemeColors sc,
    required IconData icon,
    required String label,
    required String desc,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: sc.accent),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$label: ',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: sc.primaryText,
                  ),
                ),
                TextSpan(
                  text: desc,
                  style: TextStyle(
                    fontSize: 11,
                    color: sc.mutedText,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildClueLadderItem(ScentleThemeColors sc, String turn, String desc) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: sc.surfaceSecondary,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: sc.border),
            ),
            child: Text(
              turn,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: sc.accent,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              desc,
              style: TextStyle(
                fontSize: 11,
                color: sc.primaryText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
