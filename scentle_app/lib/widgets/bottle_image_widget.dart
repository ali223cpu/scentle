import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../core/theme/scentle_theme.dart';
import '../models/perfume_model.dart';

/// Luxury perfume bottle image widget with Fragrantica CDN hotlink shielding,
/// progressive Gaussian label blurring, and procedural glass flacon fallback.
/// Studio white container blends seamlessly with white-background bottle photos.
class BottleImageWidget extends StatelessWidget {
  final PerfumeModel perfume;
  final double blurSigma;
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  const BottleImageWidget({
    super.key,
    required this.perfume,
    this.blurSigma = 0.0,
    this.width = 120.0,
    this.height = 160.0,
    this.borderRadius,
  });

  static const Map<String, String> _fimgsHeaders = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    'Referer': 'https://www.fragrantica.com/',
    'Accept': 'image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
  };

  @override
  Widget build(BuildContext context) {
    final sc = context.sc;
    final radius = borderRadius ?? BorderRadius.circular(12);

    Widget imageContent;

    if (perfume.imageUrl.trim().isEmpty) {
      imageContent = _buildProceduralFlacon(sc);
    } else {
      imageContent = CachedNetworkImage(
        imageUrl: perfume.imageUrl,
        httpHeaders: _fimgsHeaders,
        width: width,
        height: height,
        fit: BoxFit.contain,
        placeholder: (context, url) => _buildProceduralFlacon(sc, isLoading: true),
        errorWidget: (context, url, error) => _buildProceduralFlacon(sc),
      );
    }

    // Apply progressive Gaussian blur filter to obscure printed bottle names
    if (blurSigma > 0.0) {
      imageContent = ImageFiltered(
        imageFilter: ImageFilter.blur(
          sigmaX: blurSigma,
          sigmaY: blurSigma,
          tileMode: TileMode.decal,
        ),
        child: imageContent,
      );
    }

    return ClipRRect(
      borderRadius: radius,
      child: Container(
        width: width,
        height: height,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFFFF), // Pure studio white so white JPEG borders blend seamlessly
          borderRadius: radius,
          border: Border.all(color: sc.border, width: 1),
        ),
        child: Center(child: imageContent),
      ),
    );
  }

  Widget _buildProceduralFlacon(ScentleThemeColors sc, {bool isLoading = false}) {
    final primaryAccord =
        perfume.accords.isNotEmpty ? perfume.accords.first : 'amber';
    final liquidColor = AccordColors.getColor(primaryAccord);

    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(width * 0.75, height * 0.85),
            painter: LuxuryFlaconPainter(
              liquidColor: liquidColor,
              goldAccent: sc.accent,
              primaryColor: sc.accent,
            ),
          ),
          if (isLoading)
            Positioned(
              bottom: 12,
              child: SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    sc.accent.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// CustomPainter rendering a procedural glass perfume flacon with gold atomizer cap.
class LuxuryFlaconPainter extends CustomPainter {
  final Color liquidColor;
  final Color goldAccent;
  final Color? primaryColor;

  const LuxuryFlaconPainter({
    required this.liquidColor,
    required this.goldAccent,
    this.primaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Atomizer Sprayer & Cap Dimensions
    final capWidth = w * 0.32;
    final capHeight = h * 0.18;
    final neckWidth = w * 0.22;
    final neckHeight = h * 0.08;

    // Glass Body Dimensions
    final bodyTop = capHeight + neckHeight;
    final bodyHeight = h - bodyTop;
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.1, bodyTop, w * 0.8, bodyHeight),
      const Radius.circular(8),
    );

    // 1. Draw Liquid Fill Inside Bottle
    final liquidHeight = bodyHeight * 0.72;
    final liquidRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        w * 0.14,
        bodyTop + (bodyHeight - liquidHeight) - 4,
        w * 0.72,
        liquidHeight,
      ),
      const Radius.circular(6),
    );

    final liquidPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          liquidColor.withValues(alpha: 0.35),
          liquidColor.withValues(alpha: 0.85),
        ],
      ).createShader(liquidRect.outerRect);
    canvas.drawRRect(liquidRect, liquidPaint);

    // 2. Draw Heavy Base Glass Reflection
    final baseGlassRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.1, bodyTop + bodyHeight - 12, w * 0.8, 12),
      const Radius.circular(4),
    );
    final basePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(baseGlassRect, basePaint);

    // 3. Draw Outer Glass Flacon Outline
    final glassPaint = Paint()
      ..color = goldAccent.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(bodyRect, glassPaint);

    // 4. Draw Atomizer Collar / Neck
    final neckRect = Rect.fromLTWH(
      (w - neckWidth) / 2,
      capHeight,
      neckWidth,
      neckHeight,
    );
    final neckPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          const Color(0xFFE5C158),
          goldAccent,
          const Color(0xFF8C6F12),
        ],
      ).createShader(neckRect);
    canvas.drawRect(neckRect, neckPaint);

    // 5. Draw Gold Flacon Cap
    final capRect = RRect.fromRectAndRadius(
      Rect.fromLTWH((w - capWidth) / 2, 0, capWidth, capHeight),
      const Radius.circular(4),
    );
    final capPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFFF3E5AB),
          goldAccent,
          const Color(0xFF8C6F12),
        ],
      ).createShader(capRect.outerRect);
    canvas.drawRRect(capRect, capPaint);

    // 6. Draw Subtle Glass Highlight Sheen
    final sheenPath = Path()
      ..moveTo(w * 0.2, bodyTop + 8)
      ..lineTo(w * 0.2, bodyTop + bodyHeight - 16);
    final sheenPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(sheenPath, sheenPaint);
  }

  @override
  bool shouldRepaint(covariant LuxuryFlaconPainter oldDelegate) {
    return oldDelegate.liquidColor != liquidColor ||
        oldDelegate.goldAccent != goldAccent ||
        oldDelegate.primaryColor != primaryColor;
  }
}
