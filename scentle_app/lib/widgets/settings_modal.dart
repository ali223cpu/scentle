import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/theme/scentle_theme.dart';
import '../providers/multiplayer_provider.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import 'how_to_play_modal.dart';

/// Luxury settings and nominative fair-use modal for Scentle
/// with dual theme toggle (Warm Atelier Light / Noir Dark).
class SettingsModal extends StatefulWidget {
  const SettingsModal({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => const SettingsModal(),
    );
  }

  @override
  State<SettingsModal> createState() => _SettingsModalState();
}

class _SettingsModalState extends State<SettingsModal> {
  final TextEditingController _nicknameController = TextEditingController();
  late bool _hapticEnabled;
  late bool _soundEnabled;
  late bool _dailyReminderEnabled;
  late String _playerId;

  @override
  void initState() {
    super.initState();
    final storage = StorageService.instance;
    _hapticEnabled = storage.isHapticEnabled();
    _soundEnabled = storage.isSoundEnabled();
    _dailyReminderEnabled = NotificationService.instance.isRemindersEnabled();
    _playerId = storage.getOrCreatePlayerId();
    _nicknameController.text = storage.getPlayerNickname();
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final storage = StorageService.instance;
    final sc = context.sc;
    ThemeProvider? themeProvider;
    try {
      themeProvider = context.watch<ThemeProvider>();
    } catch (_) {
      themeProvider = null;
    }
    final isDark = themeProvider?.isDark ?? (Theme.of(context).brightness == Brightness.dark);

    return Dialog(
      backgroundColor: sc.cardSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: sc.border, width: 1.2),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
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
                        Icon(Icons.tune_outlined, color: sc.primaryText, size: 20),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'ATELIER SETTINGS',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2.0,
                              color: sc.primaryText,
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
              const SizedBox(height: 16),

              // 1. Perfumer Identity
              _buildSectionTitle(sc, 'OLFACTORY IDENTITY'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: sc.surfaceSecondary,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: sc.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Perfumer Nickname',
                      style: TextStyle(fontSize: 11, color: sc.mutedText),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _nicknameController,
                            maxLength: 18,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: sc.primaryText,
                            ),
                            decoration: InputDecoration(
                              counterText: '',
                              isDense: true,
                              filled: true,
                              fillColor: sc.cardSurface,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: BorderSide(color: sc.border),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: BorderSide(color: sc.inputBorder),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () async {
                            final newName = _nicknameController.text.trim();
                            if (newName.isNotEmpty) {
                              await storage.savePlayerNickname(newName);
                              if (!context.mounted) return;
                              await context.read<MultiplayerProvider>().setNickname(newName);
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Nickname saved successfully!'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: sc.ctaBackground,
                            foregroundColor: sc.ctaForeground,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          child: const Text('SAVE', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    Divider(height: 20, color: sc.divider),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Player ID (Anonymous)',
                                style: TextStyle(fontSize: 11, color: sc.mutedText),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _playerId,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontFamily: 'monospace',
                                  color: sc.accent,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.copy, size: 16, color: sc.mutedText),
                          tooltip: 'Copy ID',
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: _playerId));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Copied Player ID to clipboard'),
                                duration: Duration(seconds: 1),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // 2. Preferences & Theme Toggle
              _buildSectionTitle(sc, 'PREFERENCES'),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: sc.surfaceSecondary,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: sc.border),
                ),
                child: Column(
                  children: [
                    // Dual Theme Toggle Switch
                    SwitchListTile(
                      title: Text(
                        'Noir Dark Mode',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: sc.primaryText),
                      ),
                      subtitle: Text(
                        isDark ? 'Active: Noir Obsidian Mode' : 'Active: Warm Atelier Paper',
                        style: TextStyle(fontSize: 11, color: sc.mutedText),
                      ),
                      secondary: Icon(
                        isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                        color: sc.accent,
                      ),
                      activeThumbColor: sc.accent,
                      value: isDark,
                      onChanged: (val) {
                        themeProvider?.toggle(storage.settingsBox);
                      },
                    ),
                    Divider(height: 1, color: sc.divider),

                    SwitchListTile(
                      title: Text(
                        'Haptic Feedback',
                        style: TextStyle(fontSize: 13, color: sc.primaryText),
                      ),
                      subtitle: Text(
                        'Tactile vibrations on guess evaluations',
                        style: TextStyle(fontSize: 11, color: sc.mutedText),
                      ),
                      secondary: Icon(Icons.vibration, color: sc.mutedText),
                      activeThumbColor: sc.accent,
                      value: _hapticEnabled,
                      onChanged: (val) async {
                        setState(() => _hapticEnabled = val);
                        await storage.setHapticEnabled(val);
                      },
                    ),
                    Divider(height: 1, color: sc.divider),

                    SwitchListTile(
                      title: Text(
                        'Sound Effects',
                        style: TextStyle(fontSize: 13, color: sc.primaryText),
                      ),
                      subtitle: Text(
                        'Acoustic chimes for clue reveals',
                        style: TextStyle(fontSize: 11, color: sc.mutedText),
                      ),
                      secondary: Icon(Icons.volume_up_outlined, color: sc.mutedText),
                      activeThumbColor: sc.accent,
                      value: _soundEnabled,
                      onChanged: (val) async {
                        setState(() => _soundEnabled = val);
                        await storage.setSoundEnabled(val);
                      },
                    ),
                    Divider(height: 1, color: sc.divider),

                    SwitchListTile(
                      title: Text(
                        'Daily Streak Reminder',
                        style: TextStyle(fontSize: 13, color: sc.primaryText),
                      ),
                      subtitle: Text(
                        'Evening notification at 8:00 PM if unplayed',
                        style: TextStyle(fontSize: 11, color: sc.mutedText),
                      ),
                      secondary: Icon(Icons.notifications_active_outlined, color: sc.mutedText),
                      activeThumbColor: sc.accent,
                      value: _dailyReminderEnabled,
                      onChanged: (val) async {
                        setState(() => _dailyReminderEnabled = val);
                        await NotificationService.instance.setRemindersEnabled(val);
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // 3. Tutorial Guide Button
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  HowToPlayModal.show(context);
                },
                icon: Icon(Icons.menu_book_outlined, color: sc.primaryText, size: 18),
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'HOW TO PLAY & FORMULATION RULES',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: sc.primaryText,
                    ),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: sc.border),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),

              const SizedBox(height: 20),

              // 4. Nominative Fair-Use & Trademark Notice
              _buildSectionTitle(sc, 'NOMINATIVE FAIR-USE & LEGAL NOTICE'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: sc.surfaceSecondary,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: sc.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.verified_user_outlined,
                          size: 16,
                          color: sc.accent,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'TRADEMARK & COPYRIGHT NOTICE',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                              color: sc.accent,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Scentle is an independent educational and entertainment fragrance deduction game.\n\n'
                      'All perfume trademarks, brand names, product titles, bottle designs, and fragrance pyramids referenced in this application are the exclusive intellectual property of their respective fashion houses and creators.\n\n'
                      'References to brand names and fragrance titles are made strictly under Nominative Fair Use principles for descriptive identification and educational comparative review. Scentle is not sponsored, endorsed, affiliated with, or associated with any perfume manufacturer or brand holder.\n\n'
                      'Dataset catalog information is attributed to public fragrance research and community documentation on Fragrantica.',
                      style: TextStyle(
                        fontSize: 10,
                        color: sc.mutedText,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Version Footer
              Center(
                child: Text(
                  'Scentle v1.0.0 • Offline Olfactory Engine',
                  style: TextStyle(fontSize: 10, color: sc.mutedText),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(ScentleThemeColors sc, String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
        color: sc.accent,
      ),
    );
  }
}
