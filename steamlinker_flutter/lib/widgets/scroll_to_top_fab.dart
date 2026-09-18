import 'package:flutter/material.dart';
import '../theme/colors.dart';

/// Botón flotante "volver arriba" para listas largas (Descubrir,
/// Publicaciones). Aparece solo después de bajar un poco, y anima el
/// scroll de vuelta a 0 en vez de saltar de golpe.
class ScrollToTopFab extends StatefulWidget {
  final ScrollController controller;
  /// Offset en la esquina donde se dibuja, para no chocar con otro FAB de
  /// la misma pantalla (ej. "Crear" en Publicaciones, que vive abajo a la
  /// derecha) — por defecto abajo a la izquierda.
  final Alignment alignment;

  const ScrollToTopFab({
    super.key,
    required this.controller,
    this.alignment = Alignment.bottomLeft,
  });

  @override
  State<ScrollToTopFab> createState() => _ScrollToTopFabState();
}

class _ScrollToTopFabState extends State<ScrollToTopFab> {
  static const _umbral = 400.0;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    final mostrar = widget.controller.hasClients &&
        widget.controller.offset > _umbral;
    if (mostrar != _visible) {
      setState(() => _visible = mostrar);
    }
  }

  void _subir() {
    widget.controller.animateTo(
      0,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: widget.alignment,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: AnimatedOpacity(
          opacity: _visible ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: IgnorePointer(
            ignoring: !_visible,
            child: FloatingActionButton.small(
              onPressed: _subir,
              backgroundColor: SteamColors.bgCard,
              foregroundColor: SteamColors.light,
              elevation: 2,
              child: const Icon(Icons.keyboard_arrow_up_rounded),
            ),
          ),
        ),
      ),
    );
  }
}
