import 'package:flutter/material.dart';
import '../theme/colors.dart';

/// Miniatura de carátula de juego (26x26), usada para mostrar muestras de
/// "juegos en común" -- en Descubrir (entre dos usuarios) y en las tarjetas
/// de publicación (entre el autor y quien mira).
class MiniCaratula extends StatelessWidget {
  final String? headerimg;
  final String? nombre;

  const MiniCaratula({super.key, required this.headerimg, this.nombre});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: 'Carátula de ${nombre ?? 'juego'}',
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          color: SteamColors.bgInput,
          image: headerimg != null && headerimg!.isNotEmpty
              ? DecorationImage(
                  image: NetworkImage(headerimg!),
                  fit: BoxFit.cover,
                )
              : null,
          border: Border.all(color: SteamColors.border),
        ),
        child: headerimg == null || headerimg!.isEmpty
            ? const Icon(
                Icons.videogame_asset_outlined,
                size: 13,
                color: SteamColors.muted,
              )
            : null,
      ),
    );
  }
}
