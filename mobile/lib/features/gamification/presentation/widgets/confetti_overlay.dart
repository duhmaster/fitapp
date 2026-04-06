import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Lightweight confetti: short-lived falling rectangles (no extra packages).
class ConfettiOverlay extends StatefulWidget {
  const ConfettiOverlay({super.key, this.duration = const Duration(milliseconds: 2200)});

  final Duration duration;

  @override
  State<ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<ConfettiOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: widget.duration)..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          return CustomPaint(
            painter: _ConfettiPainter(progress: _c.value),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({required this.progress});

  final double progress;

  static final _rand = math.Random(42);
  static final List<_Piece> _pieces = List.generate(28, (_) {
    return _Piece(
      x: _rand.nextDouble(),
      delay: _rand.nextDouble() * 0.35,
      speed: 0.4 + _rand.nextDouble() * 0.9,
      hue: _rand.nextDouble(),
      w: 4 + _rand.nextDouble() * 6,
      h: 6 + _rand.nextDouble() * 10,
    );
  });

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress;
    for (final p in _pieces) {
      final localT = ((t - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (localT <= 0) continue;
      final y = -20 + localT * (size.height + 40) * p.speed;
      final x = p.x * size.width + math.sin(localT * math.pi * 2) * 12;
      final opacity = (1 - localT) * 0.85;
      final paint = Paint()
        ..color = HSVColor.fromAHSV(opacity, 360 * p.hue, 0.55, 0.95).toColor();
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(localT * math.pi * 0.5);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: p.w, height: p.h), const Radius.circular(2)),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) => oldDelegate.progress != progress;
}

class _Piece {
  _Piece({
    required this.x,
    required this.delay,
    required this.speed,
    required this.hue,
    required this.w,
    required this.h,
  });

  final double x;
  final double delay;
  final double speed;
  final double hue;
  final double w;
  final double h;
}
