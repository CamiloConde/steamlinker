import 'package:flutter/material.dart';

/// Limita el ancho del contenido de una pantalla cuando el espacio
/// disponible es de escritorio, para que listas de una sola columna
/// (pensadas para móvil) no se vean estiradas de borde a borde en
/// monitores anchos. En móvil no hace nada (child ocupa todo el ancho
/// como siempre).
///
/// IMPORTANTE: solo usar envolviendo contenido que NO sea scrolleable
/// directamente (un Column simple, por ejemplo). Si el hijo es (o
/// contiene directamente) un SingleChildScrollView/ListView, este widget
/// angosta el propio Scrollable -- su área interactiva (donde el mouse
/// tiene que estar para que la rueda haga scroll) queda literalmente más
/// angosta que la pantalla, aunque se vea centrado. Bug real reportado
/// por el usuario ("solo scrollea si el mouse está en el centro"): el
/// scroll dejaba de responder apenas el mouse salía de esa franja
/// angosta. Para un scrollable, usar [margenHorizontal] y aplicarlo como
/// `padding` DEL scrollable (SliverPadding no angosta el área de
/// interacción, solo el contenido visual) en vez de envolver el
/// scrollable con este widget. Ver HANDOFF.md.
class DesktopBodyWidth extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const DesktopBodyWidth({super.key, required this.child, this.maxWidth = 720});

  /// Margen horizontal simétrico para centrar contenido de hasta
  /// [maxWidth] dentro de [anchoDisponible] -- pensado para usarse como
  /// `padding` de un scrollable (ver comentario de la clase).
  static double margenHorizontal(double anchoDisponible, double maxWidth) {
    if (anchoDisponible <= maxWidth) return 0;
    return (anchoDisponible - maxWidth) / 2;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth <= maxWidth) return child;
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: child,
          ),
        );
      },
    );
  }
}
