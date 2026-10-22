import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/scentle_theme.dart';
import '../providers/game_provider.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../widgets/how_to_play_modal.dart';
import '../widgets/settings_modal.dart';
import '../widgets/stats_modal.dart';
import 'cabinet_screen.dart';
import 'game_screen.dart';
import 'multiplayer_lobby_screen.dart';

/// Warm Atelier Editorial home screen presenting game modes, daily status,
/// apothecary hero dossier, and player progression.
class HomeScreen extends StatefulWidget {
  final bool autoShowFirstLaunch;

  const HomeScreen({super.key, this.autoShowFirstLaunch = true});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Timer? _countdownTimer;
  String _timeToMidnight = '';

  @override
  void initState() {
    super.initState();
    _updateCountdown();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) _updateCountdown();
    });

    if (widget.autoShowFirstLaunch) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && StorageService.instance.isFirstLaunch()) {
          StorageService.instance.setFirstLaunchCompleted();
          HowToPlayModal.show(context);
        }
      });
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _updateCountdown() {
    final now = DateTime.now().toUtc();
    final tomorrow = DateTime.utc(now.year, now.month, now.day + 1);
    final diff = tomorrow.difference(now);
    final h = diff.inHours.toString().padLeft(2, '0');
    final m = (diff.inMinutes % 60).toString().padLeft(2, '0');
    final s = (diff.inSeconds % 60).toString().padLeft(2, '0');
    setState(() {
      _timeToMidnight = '${h}h ${m}m ${s}s';
    });
  }

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameProvider>();
    final stats = game.userStats;
    final cabinetCount = StorageService.instance.cabinetCount;
    final sc = context.sc;
    ThemeProvider? themeProvider;
    try {
      themeProvider = context.watch<ThemeProvider>();
    } catch (_) {
      themeProvider = null;
    }

    return Scaffold(
      backgroundColor: sc.scaffoldBg,
      body: SafeArea(
        child: Column(
          children: [
            // 1. Editorial Top Bar with bottom divider
            _buildEditorialTopBar(context, sc, themeProvider),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Brand Monogram Subtitle
                    Center(
                      child: Text(
                        'GRASSE • PARIS • NEW YORK',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2.4,
                          fontFamily: 'monospace',
                          color: sc.mutedText,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 2. Three-Column Stone Stat Strip
                    _buildStoneStatStrip(context, sc, stats, cabinetCount),
                    const SizedBox(height: 16),

                    // Streak Reminder Evening Banner (if active)
                    if (NotificationService.instance.shouldShowInAppReminderBanner(
                      todayCompleted: game.isDailyCompleted,
                    ))
                      _buildStreakReminderBanner(context, sc, stats.currentStreak),

                    // 3. Mode Card 1: Apothecary Dossier Hero Card (Daily Scentle)
                    _buildHeroDailyCard(context, sc, game),
                    const SizedBox(height: 16),

                    // 4. Mode Card 2: 1v1 Live Speed Duel
                    _buildMultiplayerCard(context, sc, stats.eloRating),
                    const SizedBox(height: 16),

                    // 5. Mode Card 3: Unlimited Atelier Mode
                    _buildUnlimitedCard(context, sc, game),
                    const SizedBox(height: 16),

                    // 6. Fragrance Cabinet Collection Card
                    _buildCabinetCard(context, sc, cabinetCount),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Top bar with 1.5px divider, centered serif title, stats icon box, theme & settings
  Widget _buildEditorialTopBar(
    BuildContext context,
    ScentleThemeColors sc,
    ThemeProvider? themeProvider,
  ) {
    final isDark = themeProvider?.isDark ?? (Theme.of(context).brightness == Brightness.dark);
    return Container(
      decoration: BoxDecoration(
        color: sc.scaffoldBg,
        border: Border(
          bottom: BorderSide(color: sc.heroBorder, width: 1.5),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Row(
        children: [
          // Left: Stats icon button in neat square container
          InkWell(
            onTap: () => StatsModal.show(context),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: sc.cardSurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: sc.border),
              ),
              child: Icon(Icons.bar_chart_outlined, color: sc.primaryText, size: 20),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () => HowToPlayModal.show(context),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: sc.cardSurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: sc.border),
              ),
              child: Icon(Icons.help_outline, color: sc.mutedText, size: 18),
            ),
          ),

          // Center: SCENTLE Serif Title
          Expanded(
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'SCENTLE',
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        color: sc.primaryText,
                        letterSpacing: 4.0,
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ),
          ),

          // Right: 1-Tap Theme Toggle Button
          InkWell(
            onTap: () {
              themeProvider?.toggle(StorageService.instance.settingsBox);
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: sc.cardSurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: sc.border),
              ),
              child: Icon(
                isDark
                    ? Icons.light_mode_outlined
                    : Icons.dark_mode_outlined,
                color: sc.accent,
                size: 19,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Settings Button
          InkWell(
            onTap: () => SettingsModal.show(context),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: sc.cardSurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: sc.border),
              ),
              child: Icon(Icons.tune_outlined, color: sc.primaryText, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  /// 3-column Stone Stat Strip
  Widget _buildStoneStatStrip(
    BuildContext context,
    ScentleThemeColors sc,
    dynamic stats,
    int cabinetCount,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: sc.surfaceSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: sc.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildMetricCell(
              sc: sc,
              icon: Icons.local_fire_department_outlined,
              iconColor: sc.accent,
              value: '${stats.currentStreak}',
              label: 'STREAK', // Kept 'STREAK' for widget test compatibility
              sublabel: 'DAY STREAK',
            ),
          ),
          _buildStripDivider(sc),
          Expanded(
            child: _buildMetricCell(
              sc: sc,
              icon: Icons.shield_outlined,
              iconColor: sc.accent,
              value: '${stats.eloRating}',
              label: 'APPRENTICE ELO',
            ),
          ),
          _buildStripDivider(sc),
          Expanded(
            child: InkWell(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CabinetScreen()),
              ),
              child: _buildMetricCell(
                sc: sc,
                icon: Icons.inventory_2_outlined,
                iconColor: sc.accent,
                value: '$cabinetCount',
                label: 'COLLECTION',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCell({
    required ScentleThemeColors sc,
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
    String? sublabel,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 5),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: sc.primaryText,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.9,
              color: sc.mutedText,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStripDivider(ScentleThemeColors sc) {
    return Container(
      width: 1,
      height: 32,
      color: sc.border,
      margin: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  /// Double-bordered Apothecary Hero Card (Daily Scentle)
  Widget _buildHeroDailyCard(
    BuildContext context,
    ScentleThemeColors sc,
    GameProvider game,
  ) {
    final nowUtc = DateTime.now().toUtc();
    final yearStr = nowUtc.year.toString().padLeft(4, '0');
    final monthStr = nowUtc.month.toString().padLeft(2, '0');
    final dayStr = nowUtc.day.toString().padLeft(2, '0');
    final todayStr = '$yearStr-$monthStr-$dayStr';

    final saved = StorageService.instance.getDailyProgress(todayStr);
    final isPlayed = saved != null && (saved['isGameOver'] == true || saved['isWon'] == true);
    final isWon = saved != null && (saved['isWon'] == true);
    final turnsCount = saved != null ? (saved['entries'] as List?)?.length ?? 0 : 0;

    final String statusBadge;
    final Color badgeColor;
    if (isWon) {
      statusBadge = 'SOLVED IN $turnsCount/6';
      badgeColor = sc.exactMatch;
    } else if (isPlayed) {
      statusBadge = 'ARCHIVED • MISSED';
      badgeColor = sc.missText;
    } else if (saved != null && turnsCount > 0) {
      statusBadge = 'IN PROGRESS • TURN ${turnsCount + 1}/6';
      badgeColor = sc.closeMatch;
    } else {
      statusBadge = 'READY TO PLAY';
      badgeColor = sc.accent;
    }

    return Container(
      decoration: BoxDecoration(
        color: sc.cardSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: sc.heroBorder, width: 2.0),
        boxShadow: [
          BoxShadow(
            color: sc.cardShadow,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Apothecary Dossier Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'SAMPLE N° ${game.puzzleNumber} • $todayStr',
                  style: TextStyle(
                    fontSize: 10,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    color: sc.mutedText,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: sc.accentBadgeFill,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: sc.accent.withValues(alpha: 0.5)),
                ),
                child: Text(
                  'DAILY PUZZLE',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: sc.accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Serif Heading
          Text(
            "Today's Mystery Flacon",
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: sc.primaryText,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Global synchronized olfactory deduction • 6 turns to deduce the house, year, accords, and pyramid notes.',
            style: TextStyle(
              fontSize: 12,
              color: sc.secondaryText,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),

          // Status & Countdown Strip
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: badgeColor, width: 1.0),
                ),
                child: Text(
                  statusBadge,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: badgeColor,
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.schedule_outlined, size: 14, color: sc.mutedText),
                  const SizedBox(width: 4),
                  Text(
                    'Next: $_timeToMidnight',
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: sc.mutedText,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Full-width Espresso CTA Button
          ElevatedButton(
            onPressed: () async {
              await game.startDailyGame();
              if (context.mounted) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const GameScreen(mode: GameMode.daily),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: sc.ctaBackground,
              foregroundColor: sc.ctaForeground,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.play_arrow, size: 18, color: sc.ctaForeground),
                const SizedBox(width: 6),
                Text(
                  'DAILY SCENTLE',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                    fontSize: 13,
                    color: sc.ctaForeground,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 1v1 Live Speed Duel Card
  Widget _buildMultiplayerCard(
    BuildContext context,
    ScentleThemeColors sc,
    int eloRating,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: sc.cardSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: sc.border),
        boxShadow: [
          BoxShadow(
            color: sc.cardShadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Sage Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(Icons.bolt_outlined, color: sc.accent, size: 20),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '1v1 LIVE SPEED DUEL',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                          color: sc.primaryText,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: sc.exactMatchBadgeFill,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: sc.exactMatch.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: sc.exactMatch,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '120s Arena',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: sc.exactMatch,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Simultaneous turns against a live challenger or intelligent bot with real-time ELO rating stakes.',
            style: TextStyle(
              fontSize: 12,
              color: sc.secondaryText,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),

          // Side-by-Side Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const MultiplayerLobbyScreen(),
                      ),
                    );
                  },
                  icon: Icon(Icons.flash_on, size: 15, color: sc.ctaForeground),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'QUICK MATCH',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        letterSpacing: 0.8,
                        color: sc.ctaForeground,
                      ),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: sc.ctaBackground,
                    foregroundColor: sc.ctaForeground,
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const MultiplayerLobbyScreen(),
                      ),
                    );
                  },
                  icon: Icon(Icons.pin_outlined, size: 15, color: sc.primaryText),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'ROOM CODE',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        letterSpacing: 0.8,
                        color: sc.primaryText,
                      ),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: sc.surfaceSecondary,
                    foregroundColor: sc.primaryText,
                    side: BorderSide(color: sc.border),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
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
    );
  }

  /// Unlimited Atelier Mode Card
  Widget _buildUnlimitedCard(
    BuildContext context,
    ScentleThemeColors sc,
    GameProvider game,
  ) {
    return InkWell(
      onTap: () {
        game.startUnlimitedGame();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const GameScreen(mode: GameMode.unlimited),
          ),
        );
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: sc.cardSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: sc.border),
          boxShadow: [
            BoxShadow(
              color: sc.cardShadow,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: sc.surfaceSecondary,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: sc.border),
              ),
              child: Icon(Icons.science_outlined, color: sc.accent, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ATELIER UNLIMITED',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                      color: sc.primaryText,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Infinite unmetered practice across 1,229 iconic formulations',
                    style: TextStyle(
                      fontSize: 11,
                      color: sc.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 13, color: sc.mutedText),
          ],
        ),
      ),
    );
  }

  /// Fragrance Cabinet Collection Card
  Widget _buildCabinetCard(
    BuildContext context,
    ScentleThemeColors sc,
    int count,
  ) {
    const totalFlacons = 1229;
    final progressFraction = (count / totalFlacons).clamp(0.0, 1.0);

    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const CabinetScreen()),
      ),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: sc.cardSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: sc.border),
          boxShadow: [
            BoxShadow(
              color: sc.cardShadow,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: sc.accentBadgeFill,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: sc.accent.withValues(alpha: 0.4)),
                  ),
                  child: Icon(Icons.account_balance_outlined, color: sc.accent, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'MY FRAGRANCE CABINET',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: sc.accent,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$count / $totalFlacons Flacons Collected',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: sc.primaryText,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios, size: 13, color: sc.mutedText),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progressFraction,
                minHeight: 6,
                backgroundColor: sc.surfaceSecondary,
                valueColor: AlwaysStoppedAnimation<Color>(sc.accent),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStreakReminderBanner(
    BuildContext context,
    ScentleThemeColors sc,
    int streak,
  ) {
    final message = NotificationService.instance.getReminderMessage(streak);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: sc.accentBadgeFill,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: sc.accent.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(Icons.notifications_active_outlined, color: sc.accent, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: sc.primaryText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
