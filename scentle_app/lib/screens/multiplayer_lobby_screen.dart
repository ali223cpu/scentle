import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/theme/scentle_theme.dart';
import '../providers/multiplayer_provider.dart';
import '../services/rank_service.dart';
import '../services/storage_service.dart';
import 'multiplayer_game_screen.dart';

/// Lobby screen for 1v1 multiplayer duels, private room codes, and bot practice.
class MultiplayerLobbyScreen extends StatefulWidget {
  const MultiplayerLobbyScreen({super.key});

  @override
  State<MultiplayerLobbyScreen> createState() => _MultiplayerLobbyScreenState();
}

class _MultiplayerLobbyScreenState extends State<MultiplayerLobbyScreen> {
  final TextEditingController _joinCodeController = TextEditingController();
  final TextEditingController _nicknameController = TextEditingController();
  bool _isJoining = false;
  bool _isCreating = false;
  bool _isGameScreenActive = false;

  @override
  void dispose() {
    _joinCodeController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  void _navigateToGameScreen() {
    if (_isGameScreenActive || !mounted) return;
    _isGameScreenActive = true;

    Navigator.of(context)
        .push(
          MaterialPageRoute(builder: (_) => const MultiplayerGameScreen()),
        )
        .then((_) {
          if (mounted) {
            setState(() {
              _isGameScreenActive = false;
            });
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    final multiplayer = context.watch<MultiplayerProvider>();
    final stats = StorageService.instance.getUserStats();
    final rank = RankService.getRank(stats.eloRating);
    final room = multiplayer.currentRoom;
    final sc = context.sc;

    // Auto-navigate to game screen when room transitions to 'playing'
    if (room != null && room.status == 'playing' && !_isGameScreenActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigateToGameScreen();
      });
    }

    return Scaffold(
      backgroundColor: sc.scaffoldBg,
      appBar: AppBar(
        backgroundColor: sc.scaffoldBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: sc.primaryText),
          onPressed: () {
            if (room != null && room.status == 'waiting') {
              multiplayer.leaveRoom();
            }
            Navigator.of(context).pop();
          },
        ),
        title: Text(
          '1v1 SPEED DUEL',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 2.0,
            color: sc.primaryText,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 1. Player Profile & Rank Card
            _buildProfileCard(context, sc, multiplayer, stats.eloRating, rank),

            const SizedBox(height: 20),

            if (multiplayer.errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: sc.errorRed.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: sc.errorRed.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: sc.errorRed, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        multiplayer.errorMessage!,
                        style: TextStyle(color: sc.errorRed, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // 2. Card A: Quick Match / Radar Matchmaking
            if (multiplayer.isMatchmaking)
              _buildRadarMatchmakingCard(context, sc, multiplayer)
            else
              _buildQuickMatchCard(context, sc, multiplayer),

            const SizedBox(height: 16),

            // 3. Card B: Create Private Room (or Waiting Room Banner)
            if (room != null && room.status == 'waiting')
              _buildWaitingHostCard(context, sc, multiplayer, room.roomCode)
            else
              _buildCreateRoomCard(context, sc, multiplayer),

            const SizedBox(height: 16),

            // 4. Card C: Join Friend's Room
            _buildJoinRoomCard(context, sc, multiplayer),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard(
    BuildContext context,
    ScentleThemeColors sc,
    MultiplayerProvider multiplayer,
    int eloRating,
    PerfumerRank rank,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: sc.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: sc.border),
        boxShadow: [
          BoxShadow(
            color: sc.cardShadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: rank.color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(color: rank.color.withValues(alpha: 0.5)),
            ),
            child: Icon(rank.icon, color: rank.color, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        multiplayer.myNickname,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: sc.primaryText,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.edit, size: 16, color: sc.accent),
                      padding: const EdgeInsets.only(left: 4),
                      constraints: const BoxConstraints(),
                      tooltip: 'Edit Nickname',
                      onPressed: () => _showEditNicknameDialog(context, sc, multiplayer),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  rank.title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: rank.color,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: sc.surfaceSecondary,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: sc.border),
            ),
            child: Column(
              children: [
                Text(
                  '$eloRating',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: sc.accent,
                  ),
                ),
                Text(
                  'ELO',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: sc.mutedText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickMatchCard(
    BuildContext context,
    ScentleThemeColors sc,
    MultiplayerProvider multiplayer,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: sc.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: sc.border),
        boxShadow: [
          BoxShadow(
            color: sc.cardShadow,
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bolt_outlined, color: sc.accent, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'QUICK MATCH (1v1 SPEED DUEL)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: sc.primaryText,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Pairs with an online perfumer in <6s. 120-second clock, simultaneous turns, and live opponent color clues!',
            style: TextStyle(fontSize: 12, color: sc.secondaryText, height: 1.4),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => multiplayer.startQuickMatch(),
                  icon: Icon(Icons.radar, size: 16, color: sc.ctaForeground),
                  label: Text('FIND OPPONENT', style: TextStyle(color: sc.ctaForeground)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: sc.ctaBackground,
                    foregroundColor: sc.ctaForeground,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: () async {
                  await multiplayer.startBotMatch();
                  if (context.mounted) _navigateToGameScreen();
                },
                icon: Icon(Icons.smart_toy_outlined, size: 16, color: sc.primaryText),
                label: Text('VS AI BOT', style: TextStyle(color: sc.primaryText)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: sc.primaryText,
                  side: BorderSide(color: sc.border),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRadarMatchmakingCard(
    BuildContext context,
    ScentleThemeColors sc,
    MultiplayerProvider multiplayer,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: sc.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: sc.accent, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: sc.cardShadow,
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          RadarScanningWidget(accentColor: sc.accent),
          const SizedBox(height: 16),
          Text(
            'SEARCHING FOR OPPONENT NOSE...',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.4,
              color: sc.primaryText,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Scanning public ateliers... (${multiplayer.matchmakingElapsedSeconds}s / 6s)\nAuto-pairs with expert AI bot if no human responds.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: sc.mutedText,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => multiplayer.cancelQuickMatch(),
            icon: Icon(Icons.close, size: 16, color: sc.errorRed),
            label: Text(
              'CANCEL SEARCH',
              style: TextStyle(color: sc.errorRed, fontWeight: FontWeight.bold),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: sc.errorRed),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateRoomCard(
    BuildContext context,
    ScentleThemeColors sc,
    MultiplayerProvider multiplayer,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: sc.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: sc.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.add_circle_outline, color: sc.primaryText, size: 20),
              const SizedBox(width: 8),
              Text(
                'HOST PRIVATE DUEL',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: sc.primaryText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Generate a 4-letter room code and challenge a friend directly.',
            style: TextStyle(fontSize: 12, color: sc.mutedText),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _isCreating
                  ? null
                  : () async {
                      setState(() => _isCreating = true);
                      try {
                        await multiplayer.createPrivateRoom();
                      } finally {
                        if (mounted) setState(() => _isCreating = false);
                      }
                    },
              style: OutlinedButton.styleFrom(
                foregroundColor: sc.primaryText,
                side: BorderSide(color: sc.border),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: _isCreating
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: sc.accent),
                    )
                  : const Text('CREATE PRIVATE ROOM', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaitingHostCard(
    BuildContext context,
    ScentleThemeColors sc,
    MultiplayerProvider multiplayer,
    String roomCode,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: sc.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: sc.heroBorder, width: 2.0),
        boxShadow: [
          BoxShadow(
            color: sc.cardShadow,
            blurRadius: 18,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'ROOM READY • SHARE CODE WITH CHALLENGER',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              color: sc.accent,
            ),
          ),
          const SizedBox(height: 14),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: roomCode.split('').map((char) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: sc.surfaceSecondary,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: sc.border),
                  ),
                  child: Text(
                    char,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: sc.primaryText,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: roomCode));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Room code "$roomCode" copied to clipboard!')),
                  );
                },
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('COPY CODE'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: sc.primaryText,
                  side: BorderSide(color: sc.border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: () => multiplayer.leaveRoom(),
                child: Text('CANCEL', style: TextStyle(color: sc.mutedText)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 2, color: sc.accent),
              ),
              const SizedBox(width: 8),
              Text(
                'Waiting for challenger to connect...',
                style: TextStyle(fontSize: 11, color: sc.mutedText),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildJoinRoomCard(
    BuildContext context,
    ScentleThemeColors sc,
    MultiplayerProvider multiplayer,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: sc.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: sc.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.meeting_room_outlined, color: sc.primaryText, size: 20),
              const SizedBox(width: 8),
              Text(
                'JOIN FRIEND\'S ROOM',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: sc.primaryText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Enter the 4-character code provided by your challenger.',
            style: TextStyle(fontSize: 12, color: sc.mutedText),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _joinCodeController,
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 4,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4.0,
                    color: sc.primaryText,
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: 'CODE',
                    hintStyle: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 16,
                      color: sc.mutedText.withValues(alpha: 0.5),
                    ),
                    filled: true,
                    fillColor: sc.surfaceSecondary,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: sc.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: sc.inputBorder, width: 2.0),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _isJoining
                    ? null
                    : () async {
                        final code = _joinCodeController.text.trim().toUpperCase();
                        if (code.length != 4) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please enter a 4-letter room code')),
                          );
                          return;
                        }
                        setState(() => _isJoining = true);
                        try {
                          final success = await multiplayer.joinPrivateRoom(code);
                          if (success && mounted) {
                            _navigateToGameScreen();
                          }
                        } finally {
                          if (mounted) setState(() => _isJoining = false);
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: sc.ctaBackground,
                  foregroundColor: sc.ctaForeground,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: _isJoining
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: sc.ctaForeground),
                      )
                    : const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('JOIN DUEL', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showEditNicknameDialog(
    BuildContext context,
    ScentleThemeColors sc,
    MultiplayerProvider multiplayer,
  ) {
    _nicknameController.text = multiplayer.myNickname;

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: sc.cardSurface,
        title: Text(
          'Edit Perfumer Nickname',
          style: TextStyle(color: sc.primaryText, fontSize: 16),
        ),
        content: TextField(
          controller: _nicknameController,
          autofocus: true,
          maxLength: 18,
          style: TextStyle(color: sc.primaryText),
          decoration: InputDecoration(
            hintText: 'Enter new nickname',
            hintStyle: TextStyle(color: sc.mutedText),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: sc.accent),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('CANCEL', style: TextStyle(color: sc.mutedText)),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = _nicknameController.text.trim();
              if (newName.isNotEmpty) {
                await multiplayer.setNickname(newName);
              }
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: sc.ctaBackground,
              foregroundColor: sc.ctaForeground,
            ),
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
  }
}

/// Animated radar scanning widget with sonar sweep and range rings.
class RadarScanningWidget extends StatefulWidget {
  final Color? accentColor;

  const RadarScanningWidget({super.key, this.accentColor});

  @override
  State<RadarScanningWidget> createState() => _RadarScanningWidgetState();
}

class _RadarScanningWidgetState extends State<RadarScanningWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.accentColor ?? const Color(0xFFB08228);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: const Size(120, 120),
          painter: RadarPainter(progress: _controller.value, accentColor: color),
        );
      },
    );
  }
}

class RadarPainter extends CustomPainter {
  final double progress;
  final Color accentColor;

  RadarPainter({required this.progress, required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    final circlePaint = Paint()
      ..color = accentColor.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Draw concentric radar range rings
    canvas.drawCircle(center, maxRadius * 0.33, circlePaint);
    canvas.drawCircle(center, maxRadius * 0.66, circlePaint);
    canvas.drawCircle(center, maxRadius, circlePaint);

    // Crosshairs
    final linePaint = Paint()
      ..color = accentColor.withValues(alpha: 0.15)
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(center.dx, 0), Offset(center.dx, size.height), linePaint);
    canvas.drawLine(Offset(0, center.dy), Offset(size.width, center.dy), linePaint);

    // Rotating sweep sector
    final angle = progress * 2 * pi;
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        startAngle: 0.0,
        endAngle: pi / 2,
        colors: [
          accentColor.withValues(alpha: 0.45),
          Colors.transparent,
        ],
        transform: GradientRotation(angle - pi / 2),
      ).createShader(Rect.fromCircle(center: center, radius: maxRadius))
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, maxRadius, sweepPaint);

    // Center pulse blip
    final blipPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 4, blipPaint);
  }

  @override
  bool shouldRepaint(covariant RadarPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.accentColor != accentColor;
}
