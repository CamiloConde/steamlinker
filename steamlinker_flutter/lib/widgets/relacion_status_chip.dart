import 'package:flutter/material.dart';
import '../theme/radii.dart';
import '../core/utils/relacion_helper.dart';

class RelacionStatusChip extends StatelessWidget {
  final RelacionResumen? relacion;

  const RelacionStatusChip({super.key, this.relacion});

  @override
  Widget build(BuildContext context) {
    final etiqueta = relacion?.etiquetaPrincipal;
    if (etiqueta == null) return const SizedBox.shrink();

    final color = relacion!.colorEtiqueta;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(SteamRadii.sm),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        etiqueta,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class RelacionStatusRow extends StatelessWidget {
  final RelacionResumen? relacion;

  const RelacionStatusRow({super.key, this.relacion});

  @override
  Widget build(BuildContext context) {
    final etiqueta = relacion?.etiquetaPrincipal;
    if (etiqueta == null) return const SizedBox.shrink();

    final color = relacion!.colorEtiqueta;
    IconData icon;
    if (relacion!.matchAceptado) {
      icon = Icons.handshake;
    } else if (relacion!.sonAmigos) {
      icon = Icons.people;
    } else if (relacion!.matchPendiente || relacion!.amistadPendiente) {
      icon = Icons.hourglass_top;
    } else {
      icon = Icons.info_outline;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(SteamRadii.sm),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              etiqueta,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
