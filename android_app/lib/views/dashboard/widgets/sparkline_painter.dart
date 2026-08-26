import 'dart:math' as math;
import 'package:flutter/material.dart';

class SparklineWidget extends StatelessWidget {
  final List<double> temperatures;
  final Color color;
  final double height;

  const SparklineWidget({
    super.key,
    required this.temperatures,
    required this.color,
    this.height = 48.0,
  });

  @override
  Widget build(BuildContext context) {
    if (temperatures.length < 2) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 12),
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _SparklinePainter(
          temperatures: temperatures,
          color: color,
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> temperatures;
  final Color color;

  _SparklinePainter({
    required this.temperatures,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (temperatures.length < 2) return;

    final double pad = 6.0;
    final double width = size.width;
    final double height = size.height;

    double minT = temperatures.reduce(math.min);
    double maxT = temperatures.reduce(math.max);
    if (maxT - minT < 1.0) {
      minT -= 0.5;
      maxT += 0.5;
    }

    final double range = maxT - minT;

    double getX(int index) {
      return pad + (width - 2 * pad) * (index / (temperatures.length - 1));
    }

    double getY(double val) {
      return height - pad - (height - 2 * pad) * ((val - minT) / range);
    }

    final linePath = Path();
    final fillPath = Path();

    final firstX = getX(0);
    final firstY = getY(temperatures[0]);

    linePath.moveTo(firstX, firstY);
    fillPath.moveTo(firstX, height);
    fillPath.lineTo(firstX, firstY);

    for (int i = 1; i < temperatures.length; i++) {
      final x = getX(i);
      final y = getY(temperatures[i]);
      linePath.lineTo(x, y);
      fillPath.lineTo(x, y);
    }

    final lastX = getX(temperatures.length - 1);
    final lastY = getY(temperatures.last);

    fillPath.lineTo(lastX, height);
    fillPath.close();

    // Gradient fill below polyline
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        color.withAlpha(50),
        color.withAlpha(0),
      ],
    );

    final fillPaint = Paint()
      ..shader = gradient.createShader(Rect.fromLTWH(0, 0, width, height))
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);

    // Polyline stroke
    final strokePaint = Paint()
      ..color = color.withAlpha(115)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    canvas.drawPath(linePath, strokePaint);

    // Latest endpoint dot
    final dotPaint = Paint()
      ..color = color.withAlpha(220)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(lastX, lastY), 3.5, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    return oldDelegate.temperatures != temperatures || oldDelegate.color != color;
  }
}
