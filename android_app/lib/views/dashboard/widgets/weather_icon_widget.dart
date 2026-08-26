import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../models/weather_code.dart';

/// A rich, modern, vector-rendered weather visual widget.
/// Replaces flat text emojis with stylized volumetric weather illustrations,
/// glowing suns, layered 3D clouds, crescent moons, and animated rain.
class WeatherVisualWidget extends StatefulWidget {
  final WeatherCategory category;
  final double size;
  final bool animate;

  const WeatherVisualWidget({
    super.key,
    required this.category,
    this.size = 64,
    this.animate = true,
  });

  @override
  State<WeatherVisualWidget> createState() => _WeatherVisualWidgetState();
}

class _WeatherVisualWidgetState extends State<WeatherVisualWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    if (widget.animate) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant WeatherVisualWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.animate && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            size: Size(widget.size, widget.size),
            painter: _WeatherPainter(
              category: widget.category,
              progress: widget.animate ? _controller.value : 0.0,
            ),
          );
        },
      ),
    );
  }
}

class _WeatherPainter extends CustomPainter {
  final WeatherCategory category;
  final double progress;

  _WeatherPainter({
    required this.category,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Scale everything from a canonical 100x100 coordinate grid
    final double scale = size.width / 100.0;
    canvas.save();
    canvas.scale(scale, scale);

    switch (category) {
      case WeatherCategory.sunny:
        _drawSunny(canvas);
        break;
      case WeatherCategory.clear:
        _drawClearNight(canvas);
        break;
      case WeatherCategory.slightlyCloudy:
        _drawSlightlyCloudy(canvas);
        break;
      case WeatherCategory.cloud:
        _drawCloudy(canvas);
        break;
      case WeatherCategory.lightRain:
        _drawRain(canvas, isLight: true);
        break;
      case WeatherCategory.rain:
        _drawRain(canvas, isLight: false);
        break;
    }

    canvas.restore();
  }

  // --- 1. SUNNY (☀️) ---
  void _drawSunny(Canvas canvas) {
    final double pulse = math.sin(progress * 2 * math.pi) * 0.05 + 1.0;
    final double rotation = progress * 2 * math.pi;

    // Ambient Warm Glow
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFF59E0B).withAlpha(80),
          const Color(0xFFFBBF24).withAlpha(30),
          Colors.transparent,
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: const Offset(50, 50), radius: 46 * pulse));
    canvas.drawCircle(const Offset(50, 50), 46 * pulse, glowPaint);

    // Sun Rays
    canvas.save();
    canvas.translate(50, 50);
    canvas.rotate(rotation);

    final rayPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFDE047), Color(0xFFF59E0B)],
      ).createShader(const Rect.fromLTWH(-3, -40, 6, 12))
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 8; i++) {
      final rayRRect = RRect.fromRectAndRadius(
        const Rect.fromLTWH(-3, -38, 6, 12),
        const Radius.circular(3),
      );
      canvas.drawRRect(rayRRect, rayPaint);
      canvas.rotate(math.pi / 4);
    }
    canvas.restore();

    // Sun Core Sphere
    final sunCorePaint = Paint()
      ..shader = const RadialGradient(
        center: Alignment(-0.3, -0.3),
        radius: 0.85,
        colors: [
          Color(0xFFFFFBEB),
          Color(0xFFFBBF24),
          Color(0xFFEA580C),
        ],
        stops: [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: const Offset(50, 50), radius: 22))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.5);

    // Drop shadow
    final shadowPaint = Paint()
      ..color = const Color(0x55F59E0B)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(const Offset(50, 53), 20, shadowPaint);

    canvas.drawCircle(const Offset(50, 50), 22, sunCorePaint);

    // Highlight sheen
    final highlightPaint = Paint()
      ..color = Colors.white.withAlpha(160)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1);
    canvas.drawArc(
      Rect.fromCircle(center: const Offset(50, 50), radius: 18),
      -math.pi * 0.75,
      math.pi * 0.45,
      false,
      highlightPaint,
    );
  }

  // --- 2. CLEAR / MOON (🌙) ---
  void _drawClearNight(Canvas canvas) {
    final double twinkle1 = (math.sin(progress * 2 * math.pi) + 1.0) / 2.0;
    final double twinkle2 = (math.cos(progress * 2 * math.pi + 1.0) + 1.0) / 2.0;

    // Ambient Night Glow
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF818CF8).withAlpha(60),
          const Color(0xFF6366F1).withAlpha(20),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: const Offset(46, 50), radius: 44));
    canvas.drawCircle(const Offset(46, 50), 44, glowPaint);

    // Twinkling Star Sparkles
    _drawStar(canvas, const Offset(74, 28), 6 + twinkle1 * 3, 0.4 + twinkle1 * 0.6);
    _drawStar(canvas, const Offset(24, 34), 4.5 + twinkle2 * 2.5, 0.3 + twinkle2 * 0.7);
    _drawStar(canvas, const Offset(78, 68), 5 + twinkle2 * 3, 0.35 + twinkle2 * 0.65);

    // Crescent Moon Shape
    final outerPath = Path()
      ..addOval(Rect.fromCircle(center: const Offset(46, 50), radius: 24));
    final cutPath = Path()
      ..addOval(Rect.fromCircle(center: const Offset(58, 42), radius: 21));

    final crescentPath = Path.combine(PathOperation.difference, outerPath, cutPath);

    // Moon Shadow
    final shadowPaint = Paint()
      ..color = const Color(0x604338CA)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawPath(crescentPath.shift(const Offset(0, 3)), shadowPaint);

    // Moon Gradient
    final moonPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFFFFFFF),
          Color(0xFFE0E7FF),
          Color(0xFFA5B4FC),
          Color(0xFF818CF8),
        ],
        stops: [0.0, 0.35, 0.75, 1.0],
      ).createShader(Rect.fromCircle(center: const Offset(46, 50), radius: 24));

    canvas.drawPath(crescentPath, moonPaint);

    // Subtle edge highlight
    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Colors.white.withAlpha(200);
    canvas.drawPath(crescentPath, rimPaint);
  }

  void _drawStar(Canvas canvas, Offset center, double size, double opacity) {
    final int alpha = (opacity.clamp(0.0, 1.0) * 255).round();
    final paint = Paint()
      ..color = const Color(0xFFFDE68A).withAlpha(alpha)
      ..style = PaintingStyle.fill;

    final glow = Paint()
      ..color = const Color(0xFFFEF08A).withAlpha((alpha * 0.5).round())
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawCircle(center, size * 0.6, glow);

    final path = Path();
    path.moveTo(center.dx, center.dy - size);
    path.quadraticBezierTo(center.dx, center.dy, center.dx + size, center.dy);
    path.quadraticBezierTo(center.dx, center.dy, center.dx, center.dy + size);
    path.quadraticBezierTo(center.dx, center.dy, center.dx - size, center.dy);
    path.quadraticBezierTo(center.dx, center.dy, center.dx, center.dy - size);
    path.close();

    canvas.drawPath(path, paint);
  }

  // --- 3. SLIGHTLY CLOUDY (⛅) ---
  void _drawSlightlyCloudy(Canvas canvas) {
    final double sunHover = math.sin(progress * 2 * math.pi) * 1.5;

    // Background Sun
    canvas.save();
    canvas.translate(64, 34 + sunHover);

    // Sun Glow
    final sunGlow = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFF59E0B).withAlpha(100),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: 26));
    canvas.drawCircle(Offset.zero, 26, sunGlow);

    // Mini Sun Rays
    final rayPaint = Paint()
      ..color = const Color(0xFFFBBF24)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 6; i++) {
      final double angle = i * (math.pi / 3) + (progress * math.pi * 0.5);
      final p1 = Offset(math.cos(angle) * 16, math.sin(angle) * 16);
      final p2 = Offset(math.cos(angle) * 21, math.sin(angle) * 21);
      canvas.drawLine(p1, p2, rayPaint);
    }

    // Mini Sun Core
    final sunPaint = Paint()
      ..shader = const RadialGradient(
        center: Alignment(-0.3, -0.3),
        colors: [Color(0xFFFFFBEB), Color(0xFFFBBF24), Color(0xFFF97316)],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: 13));
    canvas.drawCircle(Offset.zero, 13, sunPaint);
    canvas.restore();

    // Foreground 3D Volumetric Cloud
    _drawVolumetricCloud(
      canvas,
      offset: const Offset(42, 58),
      scale: 0.88,
      isDark: false,
    );
  }

  // --- 4. CLOUDY (☁️) ---
  void _drawCloudy(Canvas canvas) {
    final double floatOffset = math.sin(progress * 2 * math.pi) * 1.5;

    // Back Cloud (slightly darker for depth)
    _drawVolumetricCloud(
      canvas,
      offset: Offset(36, 44 + floatOffset * 0.5),
      scale: 0.82,
      isDark: true,
    );

    // Front Cloud (fluffy white)
    _drawVolumetricCloud(
      canvas,
      offset: Offset(48, 56 - floatOffset * 0.5),
      scale: 0.92,
      isDark: false,
    );
  }

  // --- 5 & 6. RAIN / LIGHT RAIN (🌦️ / 🌧️) ---
  void _drawRain(Canvas canvas, {required bool isLight}) {
    if (isLight) {
      // Light rain includes small sun peeking behind
      canvas.save();
      canvas.translate(66, 32);
      final sunPaint = Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.2, -0.2),
          colors: [Color(0xFFFFFBEB), Color(0xFFFBBF24), Color(0xFFEA580C)],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: 12));
      canvas.drawCircle(Offset.zero, 12, sunPaint);
      canvas.restore();
    }

    // Cloud body
    _drawVolumetricCloud(
      canvas,
      offset: const Offset(48, 48),
      scale: 0.90,
      isDark: !isLight,
      isStorm: !isLight,
    );

    // Raindrops
    final dropCount = isLight ? 3 : 5;
    final dropX = isLight ? [36.0, 48.0, 60.0] : [28.0, 38.0, 48.0, 58.0, 68.0];
    final dropSpeed = isLight ? [1.0, 1.3, 0.9] : [1.2, 1.5, 1.1, 1.4, 1.0];

    final dropPaint = Paint()
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < dropCount; i++) {
      final double cycle = (progress * dropSpeed[i] + (i * 0.25)) % 1.0;
      final double y = 66 + cycle * 22;
      final double x = dropX[i] - (cycle * 5); // slanted falling
      final double opacity = (math.sin(cycle * math.pi)).clamp(0.0, 1.0);
      final int topAlpha = ((opacity * 0.2).clamp(0.0, 1.0) * 255).round();
      final int bottomAlpha = ((opacity * 0.9).clamp(0.0, 1.0) * 255).round();

      dropPaint.shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          (isLight ? const Color(0xFF38BDF8) : const Color(0xFF60A5FA))
              .withAlpha(topAlpha),
          (isLight ? const Color(0xFF0284C7) : const Color(0xFF2563EB))
              .withAlpha(bottomAlpha),
        ],
      ).createShader(Rect.fromLTWH(x - 1.5, y, 3, 10));

      // Draw slanted rounded drop
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(-0.25); // ~15 deg slant
      final dropRRect = RRect.fromRectAndRadius(
        const Rect.fromLTWH(-1.5, 0, 3, 9),
        const Radius.circular(1.5),
      );
      canvas.drawRRect(dropRRect, dropPaint);
      canvas.restore();
    }
  }

  // --- SHARED VOLUMETRIC CLOUD BUILDER ---
  void _drawVolumetricCloud(
    Canvas canvas, {
    required Offset offset,
    required double scale,
    required bool isDark,
    bool isStorm = false,
  }) {
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    canvas.scale(scale, scale);

    // Build the cloud path composed of intersecting smooth circles + pill base
    final path = Path();
    // Base pill
    path.addRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-28, 2, 56, 18),
        const Radius.circular(9),
      ),
    );
    // Left puff
    path.addOval(Rect.fromCircle(center: const Offset(-14, 0), radius: 12));
    // Main top puff
    path.addOval(Rect.fromCircle(center: const Offset(4, -8), radius: 17));
    // Right puff
    path.addOval(Rect.fromCircle(center: const Offset(18, -1), radius: 11));

    // Cloud drop shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withAlpha(isDark ? 55 : 40)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawPath(path.shift(const Offset(0, 4)), shadowPaint);

    // Cloud Gradient
    final List<Color> colors;
    if (isStorm) {
      colors = const [
        Color(0xFF94A3B8),
        Color(0xFF64748B),
        Color(0xFF334155),
      ];
    } else if (isDark) {
      colors = const [
        Color(0xFFCBD5E1),
        Color(0xFF94A3B8),
        Color(0xFF64748B),
      ];
    } else {
      colors = const [
        Color(0xFFFFFFFF),
        Color(0xFFF1F5F9),
        Color(0xFFCBD5E1),
      ];
    }

    final cloudPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: colors,
        stops: const [0.0, 0.45, 1.0],
      ).createShader(const Rect.fromLTWH(-30, -26, 60, 48))
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, cloudPaint);

    // Top rim highlight for glass/3D feel
    if (!isStorm) {
      final highlightPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withAlpha(220),
            Colors.white.withAlpha(0),
          ],
        ).createShader(const Rect.fromLTWH(-30, -25, 60, 20))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;

      final highlightPath = Path()
        ..addArc(
          Rect.fromCircle(center: const Offset(4, -8), radius: 16.5),
          -math.pi * 0.9,
          math.pi * 0.8,
        )
        ..addArc(
          Rect.fromCircle(center: const Offset(-14, 0), radius: 11.5),
          -math.pi * 0.9,
          math.pi * 0.6,
        );

      canvas.drawPath(highlightPath, highlightPaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _WeatherPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.category != category;
  }
}
