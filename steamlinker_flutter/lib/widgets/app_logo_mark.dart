import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Marca elegida por el usuario ("1b. Dos controles"): dos siluetas de
/// control casi tocándose -- "vamos a jugar juntos", más literal. Mismas
/// coordenadas que el favicon/iconos PWA generados (ver web/icons/ y
/// web/favicon.png) para que la marca se vea igual en toda la app.
class AppLogoMark extends StatelessWidget {
  final double size;
  final Color color;

  const AppLogoMark({super.key, this.size = 24, required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _AppLogoMarkPainter(color),
    );
  }
}

class _AppLogoMarkPainter extends CustomPainter {
  final Color color;

  _AppLogoMarkPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final scale = size.width / 512;
    canvas.save();
    canvas.scale(scale);
    _drawController(canvas, paint, const Offset(196, 262), -18 * math.pi / 180);
    _drawController(canvas, paint, const Offset(316, 262), 18 * math.pi / 180);
    canvas.restore();
  }

  void _drawController(Canvas canvas, Paint paint, Offset origin, double angle) {
    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    canvas.rotate(angle);
    canvas.drawOval(const Rect.fromLTWH(-62, -32, 56, 48), paint);
    canvas.drawOval(const Rect.fromLTWH(6, -32, 56, 48), paint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(-54, -10, 108, 54), const Radius.circular(27)),
      paint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _AppLogoMarkPainter oldDelegate) => oldDelegate.color != color;
}
