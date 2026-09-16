import 'package:flutter/material.dart';

/// Limita el ancho del contenido de una pantalla cuando el espacio
/// disponible es de escritorio, para que listas de una sola columna
/// (pensadas para móvil) no se vean estiradas de borde a borde en
/// monitores anchos. En móvil no hace nada (child ocupa todo el ancho
/// como siempre).
class DesktopBodyWidth extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const DesktopBodyWidth({super.key, required this.child, this.maxWidth = 720});

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
