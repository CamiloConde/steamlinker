import 'package:flutter/material.dart';
import '../../../core/constants/publicacion_constants.dart';
import '../../../theme/colors.dart';

/// Franja de contexto bajo el encabezado del chat (wireframe turno 4,
/// opción 4e): sin esto, tres conversaciones se ven idénticas. Solo se
/// muestra si el chat nace de un match aceptado — uno que nace de una
/// amistad no tiene publicación asociada, así que no hay nada que mostrar.
class ChatContextBanner extends StatelessWidget {
  final Map<String, dynamic>? conversacion;

  const ChatContextBanner({super.key, required this.conversacion});

  @override
  Widget build(BuildContext context) {
    final conv = conversacion;
    if (conv == null) return const SizedBox.shrink();

    final tipo = conv['match_tipo_publi'] as String?;
    if (tipo == null) return const SizedBox.shrink();

    final juego = conv['match_juego_nombre'] as String?;
    final etiqueta = (juego != null && juego.isNotEmpty)
        ? juego
        : PublicacionConstants.etiquetaTipo(tipo);

    final total = conv['match_cupos_totales'] as int?;
    final ocupados = conv['match_cupos_ocupados'] as int?;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: const BoxDecoration(
        color: SteamColors.bgInput,
        border: Border(bottom: BorderSide(color: SteamColors.border)),
      ),
      child: Row(
        children: [
          const Icon(Icons.videogame_asset_outlined, size: 14, color: SteamColors.muted),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              'Match por: $etiqueta',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: SteamColors.muted, fontSize: 11.5),
            ),
          ),
          if (total != null)
            Text(
              '${ocupados ?? 0}/$total',
              style: const TextStyle(
                color: SteamColors.textSec,
                fontSize: 11.5,
                fontFamily: 'monospace',
              ),
            ),
        ],
      ),
    );
  }
}
