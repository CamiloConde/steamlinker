import 'package:flutter/material.dart';
import '../core/constants/pais_util.dart';
import '../core/constants/publicacion_constants.dart';
import '../core/utils/relacion_helper.dart';
import '../theme/colors.dart';
import '../theme/radii.dart';
import 'mini_caratula.dart';
import 'relacion_status_chip.dart';

class PublicacionCard extends StatelessWidget {
  final Map<String, dynamic> publicacion;
  final bool esMia;
  final RelacionResumen? relacion;
  final VoidCallback? onTap;
  final VoidCallback? onTapAutor;
  final VoidCallback? onCerrar;
  final VoidCallback? onEditar;

  const PublicacionCard({
    super.key,
    required this.publicacion,
    this.esMia = false,
    this.relacion,
    this.onTap,
    this.onTapAutor,
    this.onCerrar,
    this.onEditar,
  });

  @override
  Widget build(BuildContext context) {
    final juegos = (publicacion['juegos'] as List<dynamic>?) ?? [];
    final repu = publicacion['repu_usu'];
    final username = (publicacion['username_usu'] as String?) ?? 'Autor';
    final inicial = username.isNotEmpty ? username[0].toUpperCase() : '?';
    final portada = juegos.isNotEmpty
        ? juegos.first['headerimg_jg'] as String?
        : null;
    final generos = juegos.isNotEmpty
        ? ((juegos.first['generos_jg'] as List<dynamic>?) ?? [])
              .map((g) => g.toString())
              .toList()
        : <String>[];
    final enComun = publicacion['juegos_en_comun'] as int?;
    final comunes =
        ((publicacion['juegos_comunes_muestra'] as List<dynamic>?) ?? [])
            .map((j) => Map<String, dynamic>.from(j as Map))
            .toList();

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
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Encabezado: avatar + autor + reputación ────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: Row(
                  children: [
                    InkWell(
                      onTap: onTapAutor,
                      borderRadius: BorderRadius.circular(SteamRadii.avatar),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(
                            SteamRadii.avatar,
                          ),
                          gradient: const LinearGradient(
                            colors: [SteamColors.blue, SteamColors.teal],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          border: Border.all(
                            color: SteamColors.blue,
                            width: 1.5,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            inicial,
                            style: const TextStyle(
                              color: SteamColors.light,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InkWell(
                            onTap: onTapAutor,
                            child: Text(
                              username,
                              style: const TextStyle(
                                color: SteamColors.blue,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              Text(
                                PublicacionConstants.etiquetaTipo(
                                  publicacion['tipo_publi'],
                                ),
                                style: const TextStyle(
                                  color: SteamColors.textSec,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (repu != null) ...[
                                const Text(
                                  ' · ',
                                  style: TextStyle(
                                    color: SteamColors.textSec,
                                    fontSize: 11,
                                  ),
                                ),
                                Icon(
                                  Icons.star_rounded,
                                  size: 12,
                                  color: SteamColors.yellow,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  double.tryParse(
                                        repu.toString(),
                                      )?.toStringAsFixed(1) ??
                                      '$repu',
                                  style: const TextStyle(
                                    color: SteamColors.textSec,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    RelacionStatusChip(relacion: relacion),
                    if (esMia && onEditar != null)
                      IconButton(
                        icon: const Icon(
                          Icons.edit_outlined,
                          color: SteamColors.blue,
                          size: 20,
                        ),
                        tooltip: 'Editar publicación',
                        onPressed: onEditar,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                      ),
                    if (esMia && onCerrar != null)
                      IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: SteamColors.red,
                          size: 20,
                        ),
                        tooltip: 'Cerrar publicación',
                        onPressed: onCerrar,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  publicacion['titulo_publi'] ?? '',
                  style: const TextStyle(
                    color: SteamColors.light,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if ((publicacion['descrip_publi'] as String?)?.isNotEmpty ==
                  true) ...[
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    publicacion['descrip_publi'],
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: SteamColors.textSec,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
              if (generos.isNotEmpty) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: generos.take(4).map((genero) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: SteamColors.purple.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          genero,
                          style: const TextStyle(
                            color: SteamColors.purple,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              // ── Portada del juego (como un post con imagen) ────────
              if (portada != null && portada.isNotEmpty)
                AspectRatio(
                  aspectRatio: 16 / 7,
                  child: Image.network(
                    portada,
                    semanticLabel:
                        'Carátula de ${juegos.first['nom_jg'] ?? 'juego'}',
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        Container(color: SteamColors.bgCard),
                  ),
                )
              else if (juegos.isNotEmpty)
                Container(
                  height: 56,
                  color: SteamColors.bgCard,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      const Icon(
                        Icons.videogame_asset_outlined,
                        size: 18,
                        color: SteamColors.muted,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          juegos.map((j) => j['nom_jg'] ?? '').join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: SteamColors.textSec,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (enComun != null) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                  child: Row(
                    children: [
                      for (final j in comunes) ...[
                        MiniCaratula(
                          headerimg: j['headerimg_jg'] as String?,
                          nombre: j['nom_jg'] as String?,
                        ),
                        const SizedBox(width: 4),
                      ],
                      if (comunes.isNotEmpty) const SizedBox(width: 4),
                      Text(
                        enComun > 0
                            ? '$enComun juego${enComun == 1 ? '' : 's'} en común'
                            : 'Sin juegos en común',
                        style: TextStyle(
                          color: enComun > 0
                              ? SteamColors.teal
                              : SteamColors.muted,
                          fontSize: 11.5,
                          fontWeight: enComun > 0
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              // ── Pie: país + juegos + acción ─────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Row(
                  children: [
                    Icon(Icons.public, size: 14, color: SteamColors.muted),
                    const SizedBox(width: 5),
                    Text(
                      publicacion['paisfiltro_publi'] != null &&
                              publicacion['paisfiltro_publi']
                                  .toString()
                                  .isNotEmpty
                          ? PaisUtil.codigoANombre(
                              publicacion['paisfiltro_publi'],
                            )
                          : 'Todos los países',
                      style: const TextStyle(
                        color: SteamColors.textSec,
                        fontSize: 12,
                      ),
                    ),
                    if (juegos.length > 1 &&
                        (portada == null || portada.isEmpty)) ...[
                      const SizedBox(width: 10),
                      Icon(
                        Icons.videogame_asset_outlined,
                        size: 14,
                        color: SteamColors.muted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${publicacion['total_juegos'] ?? juegos.length} juegos',
                        style: const TextStyle(
                          color: SteamColors.textSec,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const Spacer(),
                    const Text(
                      'Ver detalle',
                      style: TextStyle(
                        color: SteamColors.blue,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: SteamColors.blue,
                    ),
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
