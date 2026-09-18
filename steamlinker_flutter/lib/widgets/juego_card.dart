// Tarjeta reutilizable para mostrar un juego de Steam
// Se usa en perfil, busqueda y publicaciones

import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/radii.dart';

class JuegoCard extends StatelessWidget {
  final Map<String, dynamic> juego;
  final VoidCallback? onTap;
  final Widget? accion;

  const JuegoCard({super.key, required this.juego, this.onTap, this.accion});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF13181F),
      borderRadius: BorderRadius.circular(SteamRadii.sm),
      child: InkWell(
        onTap: onTap,
        hoverColor: SteamColors.blue.withValues(alpha: 0.06),
        splashColor: SteamColors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(SteamRadii.sm),
        child: Container(
          width: 180,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(SteamRadii.sm),
            border: Border.all(color: const Color(0xFF30363D)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Imagen del juego
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(10),
                ),
                child: Image.network(
                  juego['headerimg'] ?? juego['headerimg_jg'] ?? '',
                  width: double.infinity,
                  height: 84,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 84,
                    color: const Color(0xFF1C2333),
                    child: const Icon(Icons.games, color: Color(0xFF8B949E)),
                  ),
                ),
              ),

              // Nombre y horas
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      juego['nombre'] ?? juego['nom_jg'] ?? '',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (juego['horas_usujg'] != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${juego['horas_usujg']}h jugadas',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF8B949E),
                        ),
                      ),
                    ],
                    if (accion != null) ...[const SizedBox(height: 8), accion!],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
