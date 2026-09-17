import 'package:flutter/material.dart';
import '../core/constants/pais_util.dart';
import '../core/constants/publicacion_constants.dart';
import '../core/utils/relacion_helper.dart';
import '../theme/colors.dart';
import '../theme/radii.dart';
import 'relacion_status_chip.dart';

class PublicacionCard extends StatelessWidget {
  final Map<String, dynamic> publicacion;
  final bool esMia;
  final RelacionResumen? relacion;
  final VoidCallback? onTap;
  final VoidCallback? onTapAutor;
  final VoidCallback? onCerrar;

  const PublicacionCard({
    super.key,
    required this.publicacion,
    this.esMia = false,
    this.relacion,
    this.onTap,
    this.onTapAutor,
    this.onCerrar,
  });

  @override
  Widget build(BuildContext context) {
    final juegos = (publicacion['juegos'] as List<dynamic>?) ?? [];
    final repu = publicacion['repu_usu'];

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(SteamRadii.sm),
        child: Container(
          decoration: BoxDecoration(
            color: SteamColors.bgPanel,
            borderRadius: BorderRadius.circular(SteamRadii.sm),
            border: Border.all(color: SteamColors.border),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: SteamColors.blue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(SteamRadii.sm),
                    ),
                    child: Text(
                      PublicacionConstants.etiquetaTipo(publicacion['tipo_publi']),
                      style: const TextStyle(
                        color: SteamColors.blue,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  RelacionStatusChip(relacion: relacion),
                  const Spacer(),
                  if (repu != null)
                    _InfoPill(
                      icon: Icons.star_outline,
                      label:
                          '${double.tryParse(repu.toString())?.toStringAsFixed(1) ?? repu} rep.',
                    ),
                  if (esMia && onCerrar != null)
                    IconButton(
                      icon: const Icon(Icons.close, color: SteamColors.red, size: 20),
                      tooltip: 'Cerrar publicación',
                      onPressed: onCerrar,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                publicacion['titulo_publi'] ?? '',
                style: const TextStyle(
                  color: SteamColors.light,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                publicacion['descrip_publi'] ?? 'Sin descripción',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: SteamColors.textSec, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  InkWell(
                    onTap: onTapAutor,
                    borderRadius: BorderRadius.circular(SteamRadii.sm),
                    child: _InfoPill(
                      icon: Icons.person_outline,
                      label: publicacion['username_usu'] ?? 'Autor',
                    ),
                  ),
                  _InfoPill(
                    icon: Icons.public,
                    label: publicacion['paisfiltro_publi'] != null &&
                            publicacion['paisfiltro_publi'].toString().isNotEmpty
                        ? PaisUtil.codigoANombre(publicacion['paisfiltro_publi'])
                        : 'Todos los países',
                  ),
                  _InfoPill(
                    icon: Icons.videogame_asset_outlined,
                    label: '${publicacion['total_juegos'] ?? juegos.length} juegos',
                  ),
                ],
              ),
              if (juegos.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: juegos.take(4).map<Widget>((juego) {
                    return Chip(
                      label: Text(juego['nom_jg'] ?? ''),
                      backgroundColor: SteamColors.bgCard,
                      labelStyle: const TextStyle(color: SteamColors.light, fontSize: 12),
                      visualDensity: VisualDensity.compact,
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 8),
              const Row(
                children: [
                  Icon(Icons.chevron_right, size: 16, color: SteamColors.muted),
                  SizedBox(width: 4),
                  Text(
                    'Ver detalle',
                    style: TextStyle(color: SteamColors.muted, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: SteamColors.bgCard,
        borderRadius: BorderRadius.circular(SteamRadii.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: SteamColors.muted),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(color: SteamColors.textSec, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
