import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// =============================================================================
// Semantic Color Tokens — Resolved per-theme via extension on ThemeData
// =============================================================================

/// Semantic color tokens resolved from the current [ThemeData.brightness].
/// Access via `Theme.of(context).extension<ScentleThemeColors>()!`.
class ScentleThemeColors extends ThemeExtension<ScentleThemeColors> {
  final Color scaffoldBg;
  final Color surfaceSecondary;    // Stone pill / secondary surface
  final Color cardSurface;         // Primary card background
  final Color elevatedSurface;     // Slightly lifted surface for pills/badges
  final Color border;              // Standard card border
  final Color heroBorder;          // Apothecary dossier border (hero cards)
  final Color primaryText;         // Espresso ink / bright text
  final Color secondaryText;       // Charcoal / muted-bright text
  final Color mutedText;           // Labels / captions
  final Color accent;              // Brass Gold / Champagne Gold
  final Color accentBadgeFill;     // Soft accent badge background
  final Color exactMatch;          // Sage green
  final Color exactMatchBadgeFill; // Soft sage badge bg
  final Color closeMatch;          // Terracotta amber
  final Color closeMatchBadgeFill; // Soft terracotta badge bg
  final Color closeMatchText;      // Flanker alert text
  final Color missTile;            // Miss tile bg
  final Color missText;            // Miss tile text
  final Color tileText;            // Bold white text on solid tiles
  final Color cardShadow;          // Subtle card shadow
  final Color ctaBackground;       // Primary CTA button bg
  final Color ctaForeground;       // Primary CTA button text
  final Color divider;             // Divider / separator
  final Color inputBorder;         // Search bar focused border
  final Color errorRed;

  const ScentleThemeColors({
    required this.scaffoldBg,
    required this.surfaceSecondary,
    required this.cardSurface,
    required this.elevatedSurface,
    required this.border,
    required this.heroBorder,
    required this.primaryText,
    required this.secondaryText,
    required this.mutedText,
    required this.accent,
    required this.accentBadgeFill,
    required this.exactMatch,
    required this.exactMatchBadgeFill,
    required this.closeMatch,
    required this.closeMatchBadgeFill,
    required this.closeMatchText,
    required this.missTile,
    required this.missText,
    required this.tileText,
    required this.cardShadow,
    required this.ctaBackground,
    required this.ctaForeground,
    required this.divider,
    required this.inputBorder,
    required this.errorRed,
  });

  @override
  ScentleThemeColors copyWith({
    Color? scaffoldBg,
    Color? surfaceSecondary,
    Color? cardSurface,
    Color? elevatedSurface,
    Color? border,
    Color? heroBorder,
    Color? primaryText,
    Color? secondaryText,
    Color? mutedText,
    Color? accent,
    Color? accentBadgeFill,
    Color? exactMatch,
    Color? exactMatchBadgeFill,
    Color? closeMatch,
    Color? closeMatchBadgeFill,
    Color? closeMatchText,
    Color? missTile,
    Color? missText,
    Color? tileText,
    Color? cardShadow,
    Color? ctaBackground,
    Color? ctaForeground,
    Color? divider,
    Color? inputBorder,
    Color? errorRed,
  }) {
    return ScentleThemeColors(
      scaffoldBg: scaffoldBg ?? this.scaffoldBg,
      surfaceSecondary: surfaceSecondary ?? this.surfaceSecondary,
      cardSurface: cardSurface ?? this.cardSurface,
      elevatedSurface: elevatedSurface ?? this.elevatedSurface,
      border: border ?? this.border,
      heroBorder: heroBorder ?? this.heroBorder,
      primaryText: primaryText ?? this.primaryText,
      secondaryText: secondaryText ?? this.secondaryText,
      mutedText: mutedText ?? this.mutedText,
      accent: accent ?? this.accent,
      accentBadgeFill: accentBadgeFill ?? this.accentBadgeFill,
      exactMatch: exactMatch ?? this.exactMatch,
      exactMatchBadgeFill: exactMatchBadgeFill ?? this.exactMatchBadgeFill,
      closeMatch: closeMatch ?? this.closeMatch,
      closeMatchBadgeFill: closeMatchBadgeFill ?? this.closeMatchBadgeFill,
      closeMatchText: closeMatchText ?? this.closeMatchText,
      missTile: missTile ?? this.missTile,
      missText: missText ?? this.missText,
      tileText: tileText ?? this.tileText,
      cardShadow: cardShadow ?? this.cardShadow,
      ctaBackground: ctaBackground ?? this.ctaBackground,
      ctaForeground: ctaForeground ?? this.ctaForeground,
      divider: divider ?? this.divider,
      inputBorder: inputBorder ?? this.inputBorder,
      errorRed: errorRed ?? this.errorRed,
    );
  }

  @override
  ScentleThemeColors lerp(covariant ScentleThemeColors? other, double t) {
    if (other == null) return this;
    return ScentleThemeColors(
      scaffoldBg: Color.lerp(scaffoldBg, other.scaffoldBg, t)!,
      surfaceSecondary: Color.lerp(surfaceSecondary, other.surfaceSecondary, t)!,
      cardSurface: Color.lerp(cardSurface, other.cardSurface, t)!,
      elevatedSurface: Color.lerp(elevatedSurface, other.elevatedSurface, t)!,
      border: Color.lerp(border, other.border, t)!,
      heroBorder: Color.lerp(heroBorder, other.heroBorder, t)!,
      primaryText: Color.lerp(primaryText, other.primaryText, t)!,
      secondaryText: Color.lerp(secondaryText, other.secondaryText, t)!,
      mutedText: Color.lerp(mutedText, other.mutedText, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentBadgeFill: Color.lerp(accentBadgeFill, other.accentBadgeFill, t)!,
      exactMatch: Color.lerp(exactMatch, other.exactMatch, t)!,
      exactMatchBadgeFill: Color.lerp(exactMatchBadgeFill, other.exactMatchBadgeFill, t)!,
      closeMatch: Color.lerp(closeMatch, other.closeMatch, t)!,
      closeMatchBadgeFill: Color.lerp(closeMatchBadgeFill, other.closeMatchBadgeFill, t)!,
      closeMatchText: Color.lerp(closeMatchText, other.closeMatchText, t)!,
      missTile: Color.lerp(missTile, other.missTile, t)!,
      missText: Color.lerp(missText, other.missText, t)!,
      tileText: Color.lerp(tileText, other.tileText, t)!,
      cardShadow: Color.lerp(cardShadow, other.cardShadow, t)!,
      ctaBackground: Color.lerp(ctaBackground, other.ctaBackground, t)!,
      ctaForeground: Color.lerp(ctaForeground, other.ctaForeground, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      inputBorder: Color.lerp(inputBorder, other.inputBorder, t)!,
      errorRed: Color.lerp(errorRed, other.errorRed, t)!,
    );
  }
}

// =============================================================================
// Warm Atelier (Light) Color Tokens
// =============================================================================

const _warmAtelierColors = ScentleThemeColors(
  scaffoldBg:           Color(0xFFFAF7F2), // Warm Alabaster Paper
  surfaceSecondary:     Color(0xFFF1ECE2), // Stone Pill
  cardSurface:          Color(0xFFFFFFFF), // Studio White
  elevatedSurface:      Color(0xFFF1ECE2), // Stone
  border:               Color(0xFFE2DBD0), // Standard card border
  heroBorder:           Color(0xFF161514), // Apothecary dossier border
  primaryText:          Color(0xFF161514), // Espresso Ink
  secondaryText:        Color(0xFF3D3A36), // Charcoal
  mutedText:            Color(0xFF7A756C), // Muted Label
  accent:               Color(0xFFB08228), // Brass Gold
  accentBadgeFill:      Color(0xFFF5EBD6), // Soft brass badge
  exactMatch:           Color(0xFF1B7A56), // Botanical Sage
  exactMatchBadgeFill:  Color(0xFFE3F3EC), // Soft sage badge
  closeMatch:           Color(0xFFD4751C), // Terracotta Amber
  closeMatchBadgeFill:  Color(0xFFFDF0E1), // Soft flanker alert
  closeMatchText:       Color(0xFF9A4D08), // Flanker alert text
  missTile:             Color(0xFFEAE5DC), // Miss tile
  missText:             Color(0xFF7A756C), // Miss text
  tileText:             Color(0xFFFFFFFF), // White bold text on exact/close
  cardShadow:           Color(0x0A161514), // Subtle shadow
  ctaBackground:        Color(0xFF161514), // Espresso CTA
  ctaForeground:        Color(0xFFFAF7F2), // Alabaster CTA text
  divider:              Color(0xFFE2DBD0), // Divider
  inputBorder:          Color(0xFF161514), // Search bar 2px border
  errorRed:             Color(0xFFD03030),
);

// =============================================================================
// Noir Dark Color Tokens
// =============================================================================

const _noirDarkColors = ScentleThemeColors(
  scaffoldBg:           Color(0xFF121316), // Obsidian
  surfaceSecondary:     Color(0xFF16181D), // Surface Obsidian
  cardSurface:          Color(0xFF1C1E24),
  elevatedSurface:      Color(0xFF2A2D35),
  border:               Color(0xFF2A2D35),
  heroBorder:           Color(0xFFD4AF37), // Champagne Gold hero border
  primaryText:          Color(0xFFF5F2EB), // Warm Alabaster
  secondaryText:        Color(0xFFCCC8C0),
  mutedText:            Color(0xFF9E9B93),
  accent:               Color(0xFFD4AF37), // Champagne Gold
  accentBadgeFill:      Color(0xFF2A2510),
  exactMatch:           Color(0xFF2E7D32), // Emerald
  exactMatchBadgeFill:  Color(0xFF1A3A1C),
  closeMatch:           Color(0xFFD97706), // Amber
  closeMatchBadgeFill:  Color(0xFF3A2A0A),
  closeMatchText:       Color(0xFFFFBE45),
  missTile:             Color(0xFF2A2D34), // Slate
  missText:             Color(0xFF9E9B93),
  tileText:             Color(0xFFFFFFFF),
  cardShadow:           Color(0x59000000),
  ctaBackground:        Color(0xFFD4AF37),
  ctaForeground:        Color(0xFF121316),
  divider:              Color(0xFF2A2D35),
  inputBorder:          Color(0xFFD4AF37),
  errorRed:             Color(0xFFEF4444),
);

// =============================================================================
// Legacy ScentleColors — backward compat bridge resolving from active theme
// Screens that haven't been migrated yet can still reference these statics.
// They resolve to the Warm Atelier palette when used outside a BuildContext.
// =============================================================================

/// Legacy static color palette. Prefer `Theme.of(context).extension<ScentleThemeColors>()!`
/// for theme-aware colors. These statics are retained for backward compatibility
/// with widget tests and code that doesn't have a BuildContext.
class ScentleColors {
  const ScentleColors._();

  // Warm Atelier defaults (matching new light theme)
  static const Color backgroundObsidian = Color(0xFFFAF7F2);
  static const Color surfaceObsidian = Color(0xFFF1ECE2);
  static const Color cardSurface = Color(0xFFFFFFFF);
  static const Color elevatedSurface = Color(0xFFF1ECE2);
  static const Color border = Color(0xFFE2DBD0);

  static const Color primaryText = Color(0xFF161514);
  static const Color mutedText = Color(0xFF7A756C);
  static const Color champagneGold = Color(0xFFB08228); // Brass Gold

  // Clue Evaluation Colors
  static const Color exactMatch = Color(0xFF1B7A56);
  static const Color closeMatch = Color(0xFFD4751C);
  static const Color missMatch = Color(0xFFEAE5DC);
  static const Color errorRed = Color(0xFFD03030);
}

// =============================================================================
// Accord Colors (theme-independent — same in both modes)
// =============================================================================

/// Authentic high-contrast color mappings for Fragrantica main accords.
class AccordColors {
  const AccordColors._();

  static const Map<String, Color> _accordPalette = {
    'fresh spicy': Color(0xFF26A69A),
    'amber': Color(0xFFFFB300),
    'citrus': Color(0xFFFFD54F),
    'aromatic': Color(0xFF66BB6A),
    'musky': Color(0xFFB0BEC5),
    'woody': Color(0xFF8D6E63),
    'floral': Color(0xFFF06292),
    'vanilla': Color(0xFFFFE082),
    'sweet': Color(0xFFFF8A80),
    'powdery': Color(0xFFCE93D8),
    'oud': Color(0xFF4E342E),
    'warm spicy': Color(0xFFFF7043),
    'fruity': Color(0xFFFF5252),
    'green': Color(0xFF4CAF50),
    'aquatic': Color(0xFF29B6F6),
    'marine': Color(0xFF0288D1),
    'leather': Color(0xFF795548),
    'earthy': Color(0xFF6D4C41),
    'lavender': Color(0xFF9575CD),
    'rose': Color(0xFFE91E63),
    'patchouli': Color(0xFF5D4037),
    'white floral': Color(0xFFFFF9C4),
    'yellow floral': Color(0xFFFFF176),
    'balsamic': Color(0xFFFFA726),
    'tobacco': Color(0xFFA1887F),
    'smoky': Color(0xFF78909C),
    'animalic': Color(0xFF8D6E63),
    'herbal': Color(0xFF81C784),
    'cacao': Color(0xFF5D4037),
    'coffee': Color(0xFF4E342E),
    'iris': Color(0xFF7986CB),
    'mossy': Color(0xFF558B2F),
  };

  static const Color defaultFallback = Color(0xFF717786);

  /// Returns the corresponding UI color for a given accord name with graceful fallback.
  static Color getColor(String accordName) {
    final normalized = accordName.trim().toLowerCase();
    return _accordPalette[normalized] ?? defaultFallback;
  }
}

// =============================================================================
// Theme Provider — ChangeNotifier driving the MaterialApp theme toggle
// =============================================================================

/// Manages the active theme mode with persistence via StorageService settings_box.
class ThemeProvider extends ChangeNotifier {
  static const String _storageKey = 'scentle_theme_mode';

  bool _isDark;

  /// Constructs with an initial mode. Call [loadFromStorage] after
  /// StorageService initialization to hydrate from persisted preference.
  ThemeProvider({bool isDark = false}) : _isDark = isDark;

  bool get isDark => _isDark;
  ThemeMode get themeMode => _isDark ? ThemeMode.dark : ThemeMode.light;

  /// Hydrate theme preference from Hive settings box. Safe to call before
  /// StorageService is initialized — defaults to light (Warm Atelier).
  void loadFromStorage(dynamic settingsBox) {
    if (settingsBox == null) return;
    try {
      final dynamic stored = settingsBox.get(_storageKey);
      if (stored is bool) {
        _isDark = stored;
        notifyListeners();
      }
    } catch (_) {
      // Settings box not ready yet; keep default
    }
  }

  /// Toggle between Warm Atelier ↔ Noir Dark and persist.
  void toggle(dynamic settingsBox) {
    _isDark = !_isDark;
    try {
      settingsBox?.put(_storageKey, _isDark);
    } catch (_) {
      // Fire-and-forget persistence
    }
    notifyListeners();
  }
}

// =============================================================================
// Theme Builder — constructs full ThemeData for each mode
// =============================================================================

/// Scentle Theme Builder producing Warm Atelier (light) and Noir Dark themes.
class ScentleTheme {
  const ScentleTheme._();

  /// Warm Atelier Editorial Light Theme (Le Labo / Diptyque / NYT Games inspired).
  static ThemeData get warmAtelierTheme {
    const c = _warmAtelierColors;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: c.scaffoldBg,
      canvasColor: c.scaffoldBg,
      cardColor: c.cardSurface,
      colorScheme: ColorScheme.light(
        surface: c.cardSurface,
        primary: c.ctaBackground,
        onPrimary: c.ctaForeground,
        secondary: c.accent,
        onSecondary: c.ctaForeground,
        onSurface: c.primaryText,
        error: c.errorRed,
      ),
      dividerTheme: DividerThemeData(color: c.divider, thickness: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: c.scaffoldBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: c.primaryText),
        titleTextStyle: GoogleFonts.cinzel(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: c.primaryText,
          letterSpacing: 2.0,
        ),
      ),
      iconTheme: IconThemeData(color: c.primaryText),
      textTheme: _buildTextTheme(c),
      extensions: const [_warmAtelierColors],
    );
  }

  /// Noir Dark Theme — the original obsidian luxury aesthetic.
  static ThemeData get darkTheme {
    const c = _noirDarkColors;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: c.scaffoldBg,
      canvasColor: c.scaffoldBg,
      cardColor: c.cardSurface,
      colorScheme: ColorScheme.dark(
        surface: c.cardSurface,
        primary: c.accent,
        onPrimary: c.scaffoldBg,
        secondary: c.accent,
        onSecondary: c.scaffoldBg,
        onSurface: c.primaryText,
        error: c.errorRed,
      ),
      dividerTheme: DividerThemeData(color: c.divider, thickness: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: c.scaffoldBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: c.primaryText),
        titleTextStyle: GoogleFonts.cinzel(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: c.primaryText,
          letterSpacing: 2.0,
        ),
      ),
      iconTheme: IconThemeData(color: c.primaryText),
      textTheme: _buildTextTheme(c),
      extensions: const [_noirDarkColors],
    );
  }

  static TextTheme _buildTextTheme(ScentleThemeColors c) {
    return TextTheme(
      displayLarge: GoogleFonts.cinzel(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: c.primaryText,
        letterSpacing: 1.5,
      ),
      displayMedium: GoogleFonts.cinzel(
        fontSize: 26,
        fontWeight: FontWeight.w600,
        color: c.primaryText,
        letterSpacing: 1.2,
      ),
      titleLarge: GoogleFonts.cinzel(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: c.primaryText,
        letterSpacing: 0.8,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: c.primaryText,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.normal,
        color: c.primaryText,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.normal,
        color: c.mutedText,
      ),
      labelLarge: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: c.accent,
        letterSpacing: 0.5,
      ),
    );
  }
}

// =============================================================================
// Convenience Extension for terse access
// =============================================================================

extension ScentleThemeX on BuildContext {
  /// Shorthand for `Theme.of(this).extension<ScentleThemeColors>()!`.
  ScentleThemeColors get sc =>
      Theme.of(this).extension<ScentleThemeColors>() ?? _warmAtelierColors;
}
