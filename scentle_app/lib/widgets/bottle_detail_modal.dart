import 'package:flutter/material.dart';
import '../core/theme/scentle_theme.dart';
import '../models/cabinet_entry.dart';
import '../models/perfume_model.dart';
import 'bottle_image_widget.dart';

/// Luxury collector's dossier modal presenting complete olfactory formulation,
/// bottle imagery, accords breakdown, and trophy acquisition details.
class BottleDetailModal extends StatelessWidget {
  final PerfumeModel perfume;
  final CabinetEntry? entry;

  const BottleDetailModal({
    super.key,
    required this.perfume,
    this.entry,
  });

  static Future<void> show(
    BuildContext context, {
    required PerfumeModel perfume,
    CabinetEntry? entry,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => BottleDetailModal(
        perfume: perfume,
        entry: entry,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sc = context.sc;
    final unlockedDateStr = entry != null
        ? '${entry!.unlockedAt.year}-${entry!.unlockedAt.month.toString().padLeft(2, '0')}-${entry!.unlockedAt.day.toString().padLeft(2, '0')}'
        : null;

    return Dialog(
      backgroundColor: sc.cardSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: sc.border, width: 1.2),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 680),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.auto_awesome, color: sc.accent, size: 20),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'FLACON DOSSIER',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2.0,
                              color: sc.accent,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: sc.mutedText, size: 20),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Bottle Image in Studio White Container
              Center(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: sc.cardSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: sc.border),
                  ),
                  child: BottleImageWidget(
                    perfume: perfume,
                    blurSigma: 0.0,
                    width: 140,
                    height: 170,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Brand & Title
              Text(
                perfume.brand.toUpperCase(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0,
                  color: sc.accent,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                perfume.name,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: sc.primaryText,
                ),
              ),
              const SizedBox(height: 12),

              // Trophy Acquisition Badge (if unlocked via cabinet)
              if (entry != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: sc.accentBadgeFill,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: sc.accent.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.emoji_events_outlined, size: 16, color: sc.accent),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Unlocked in ${entry!.modeDisplayTitle} • $unlockedDateStr',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: sc.accent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Essential Metadata Row
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: sc.surfaceSecondary,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: sc.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildMetaCell(sc, 'YEAR', perfume.year > 0 ? '${perfume.year}' : 'Classic'),
                    _buildMetaDivider(sc),
                    _buildMetaCell(sc, 'GENDER', perfume.gender.isNotEmpty ? perfume.gender : 'Unisex'),
                    _buildMetaDivider(sc),
                    _buildMetaCell(sc, 'ORIGIN', perfume.country.isNotEmpty ? perfume.country : 'France'),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Master Perfumer
              if (perfume.perfumer.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: sc.surfaceSecondary,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: sc.border),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.brush_outlined, size: 16, color: sc.accent),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'NOSE / MASTER PERFUMER',
                              style: TextStyle(fontSize: 10, letterSpacing: 1.2, color: sc.mutedText),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              perfume.perfumer,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: sc.primaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              // Main Accords
              if (perfume.accords.isNotEmpty) ...[
                Text(
                  'MAIN ACCORDS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                    color: sc.accent,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: perfume.accords.take(5).map((accord) {
                    final color = AccordColors.getColor(accord);
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: color.withValues(alpha: 0.7)),
                      ),
                      child: Text(
                        accord.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                          color: color,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
              ],

              // Olfactory Pyramid (Top, Middle, Base)
              Text(
                'OLFACTORY PYRAMID',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  color: sc.accent,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: sc.surfaceSecondary,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: sc.border),
                ),
                child: Column(
                  children: [
                    _buildPyramidTier(
                      sc,
                      'TOP NOTES',
                      perfume.notes.top,
                      Icons.keyboard_double_arrow_up,
                    ),
                    Divider(height: 16, color: sc.divider),
                    _buildPyramidTier(
                      sc,
                      'HEART NOTES',
                      perfume.notes.middle,
                      Icons.favorite_border,
                    ),
                    Divider(height: 16, color: sc.divider),
                    _buildPyramidTier(
                      sc,
                      'BASE NOTES',
                      perfume.notes.base,
                      Icons.keyboard_double_arrow_down,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Dismiss Button
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: sc.ctaBackground,
                  foregroundColor: sc.ctaForeground,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text(
                  'RETURN TO CABINET',
                  style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetaCell(ScentleThemeColors sc, String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 10, letterSpacing: 1.2, color: sc.mutedText),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: sc.primaryText,
          ),
        ),
      ],
    );
  }

  Widget _buildMetaDivider(ScentleThemeColors sc) {
    return Container(
      width: 1,
      height: 24,
      color: sc.border,
    );
  }

  Widget _buildPyramidTier(
    ScentleThemeColors sc,
    String label,
    List<String> notes,
    IconData icon,
  ) {
    final displayNotes = notes.isNotEmpty ? notes.join(', ') : 'Undisclosed';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: sc.accent),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: sc.mutedText,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                displayNotes,
                style: TextStyle(
                  fontSize: 12,
                  color: sc.primaryText,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
