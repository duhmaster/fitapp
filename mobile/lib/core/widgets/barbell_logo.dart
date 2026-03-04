import 'package:flutter/material.dart';

/// Barbell-style logo: horizontal bar with two weighted ends.
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
    final c = color ?? Theme.of(context).colorScheme.primary;
    final barHeight = size * 0.2;
    final endRadius = size * 0.35;
    return SizedBox(
      width: size * 1.8,
      height: size,
      child: CustomPaint(
        painter: _BarbellPainter(color: c, barHeight: barHeight, endRadius: endRadius),
      ),
    );
  }
}

class _BarbellPainter extends CustomPainter {
  _BarbellPainter({required this.color, required this.barHeight, required this.endRadius});
  final Color color;
  final double barHeight;
  final double endRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final centerY = size.height / 2;
    final barWidth = size.width - 2 * endRadius;
    final leftCenter = endRadius;
    final rightCenter = size.width - endRadius;
    // Horizontal bar
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(size.width / 2, centerY), width: barWidth, height: barHeight),
        Radius.circular(barHeight / 2),
      ),
      paint,
    );
    // Left weight
    canvas.drawCircle(Offset(leftCenter, centerY), endRadius, paint);
    canvas.drawCircle(Offset(leftCenter, centerY), endRadius * 0.5, paint..color = color.withOpacity(0.3));
    // Right weight
    paint.color = color;
    canvas.drawCircle(Offset(rightCenter, centerY), endRadius, paint);
    canvas.drawCircle(Offset(rightCenter, centerY), endRadius * 0.5, paint..color = color.withOpacity(0.3));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
