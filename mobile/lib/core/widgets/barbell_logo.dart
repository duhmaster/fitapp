import 'package:flutter/material.dart';

/// GymMore logo: barbell with a stylized growth chart overlay.
class BarbellLogo extends StatelessWidget {
  const BarbellLogo({
    super.key,
    this.size = 32,
    this.color,
  });

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final barbellColor = color ?? Colors.orange;
    final barHeight = size * 0.2;
    final endRadius = size * 0.35;
    return SizedBox(
      width: size * 1.8,
      height: size,
      child: CustomPaint(
        painter: _BarbellPainter(
          barbellColor: barbellColor,
          chartColor: Colors.black,
          barHeight: barHeight,
          endRadius: endRadius,
        ),
      ),
    );
  }
}

class _BarbellPainter extends CustomPainter {
  _BarbellPainter({
    required this.barbellColor,
    required this.chartColor,
    required this.barHeight,
    required this.endRadius,
  });
  final Color barbellColor;
  final Color chartColor;
  final double barHeight;
  final double endRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = barbellColor;
    final centerY = size.height / 2;
    final barWidth = size.width - 2 * endRadius;
    final leftCenter = endRadius;
    final rightCenter = size.width - endRadius;

    // Horizontal bar (barbell) — orange
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(size.width / 2, centerY), width: barWidth, height: barHeight),
        Radius.circular(barHeight / 2),
      ),
      paint,
    );
    // Left weight
    canvas.drawCircle(Offset(leftCenter, centerY), endRadius, paint);
    canvas.drawCircle(Offset(leftCenter, centerY), endRadius * 0.5, paint..color = barbellColor.withValues(alpha: 0.3));
    // Right weight
    paint.color = barbellColor;
    canvas.drawCircle(Offset(rightCenter, centerY), endRadius, paint);
    canvas.drawCircle(Offset(rightCenter, centerY), endRadius * 0.5, paint..color = barbellColor.withValues(alpha: 0.3));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
