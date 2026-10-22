import 'dart:async';
import 'package:flutter/material.dart';
import '../core/theme/scentle_theme.dart';

/// Clean rewarded ad service stub for unlocking mystery note clues.
/// Production-ready drop-in interface designed to be swapped with
/// Google AdMob or Unity Ads without touching game logic.
class AdService {
  AdService._();

  /// Displays an Atelier Sponsor Preview dialog with a 2-second countdown bar.
  /// Returns `true` if the ad completed and reward was earned, or `false` if dismissed early.
  static Future<bool> showRewardedHintAd(
    BuildContext context, {
    Duration duration = const Duration(seconds: 2),
  }) async {
    // If duration is zero (e.g. in automated unit tests), grant immediately
    if (duration == Duration.zero) {
      return true;
    }

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _RewardedAdDialog(duration: duration),
    );

    return result ?? false;
  }
}

class _RewardedAdDialog extends StatefulWidget {
  final Duration duration;

  const _RewardedAdDialog({required this.duration});

  @override
  State<_RewardedAdDialog> createState() => _RewardedAdDialogState();
}

class _RewardedAdDialogState extends State<_RewardedAdDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _completed = false;
  int _secondsLeft = 2;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _secondsLeft = widget.duration.inSeconds > 0 ? widget.duration.inSeconds : 1;

    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..addListener(() {
        setState(() {});
      });

    _controller.forward().then((_) {
      if (mounted) {
        setState(() {
          _completed = true;
          _secondsLeft = 0;
        });
      }
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsLeft > 1) {
        setState(() => _secondsLeft--);
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: ScentleColors.surfaceObsidian,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: ScentleColors.champagneGold, width: 1.5),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Bar with Close button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: ScentleColors.champagneGold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'ATELIER SPONSOR PREVIEW',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: ScentleColors.champagneGold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: ScentleColors.mutedText, size: 20),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Visual Sponsor Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF1F222A),
                      ScentleColors.surfaceObsidian,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: ScentleColors.border),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: ScentleColors.champagneGold.withValues(alpha: 0.12),
                      ),
                      child: const Icon(
                        Icons.auto_awesome,
                        color: ScentleColors.champagneGold,
                        size: 36,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'HAUTE PARFUMERIE ARCHIVE',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2.0,
                        color: ScentleColors.primaryText,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Unlocking secret formulation notes directly from Grasse & Paris perfumer ateliers.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: ScentleColors.mutedText,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: _controller.value,
                  backgroundColor: ScentleColors.cardSurface,
                  valueColor: const AlwaysStoppedAnimation<Color>(ScentleColors.champagneGold),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 12),

              // Status / Timer Text
              Text(
                _completed
                    ? '✨ Bonus clue unlocked!'
                    : 'Preview concluding in ${_secondsLeft}s...',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _completed ? ScentleColors.exactMatch : ScentleColors.mutedText,
                ),
              ),

              const SizedBox(height: 20),

              // Action Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _completed ? () => Navigator.of(context).pop(true) : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ScentleColors.champagneGold,
                    foregroundColor: Colors.black,
                    disabledBackgroundColor: Colors.white12,
                    disabledForegroundColor: Colors.white38,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _completed ? 'CLAIM SECRET NOTE' : 'WATCHING PREVIEW...',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.4,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
