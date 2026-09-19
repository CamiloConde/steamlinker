import 'package:flutter/material.dart';

/// Marca actual: monograma tipográfico "SM" entrelazadas -- placeholder
/// simple mientras el usuario decide un logo definitivo (pidió
/// explícitamente este concepto, el "2b" de una ronda anterior de
/// opciones mostradas en chat: las letras bien juntas, casi
/// superpuestas, para que se sientan más como una sola marca que como
/// texto). Mismas proporciones que el favicon/íconos PWA generados (ver
/// web/icons/ y web/favicon.png) para que la marca se vea igual en toda
/// la app.
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
    final fontSize = size.width * 0.58;
    final offset = size.width * 0.16;
    final cx = size.width / 2;
    final cy = size.height / 2 + size.height * 0.02;

    // Kerning apretado a mano (S y M como TextPainter separados, no un
    // solo string) para que se sienta como un monograma compacto en vez
    // de texto suelto.
    _drawLetra(canvas, 'S', Offset(cx - offset, cy), fontSize, color);
    _drawLetra(canvas, 'M', Offset(cx + offset, cy), fontSize, color);
  }

  void _drawLetra(
    Canvas canvas,
    String letra,
    Offset center,
    double fontSize,
    Color color,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: letra,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _AppLogoMarkPainter oldDelegate) =>
      oldDelegate.color != color;
}
