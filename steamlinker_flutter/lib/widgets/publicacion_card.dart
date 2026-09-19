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
    // La portada y los géneros representan la publicación -- deben salir
    // de un juego que el autor de verdad TIENE, nunca de uno que solo
    // busca (ej. mostrar la carátula de Spider-Man 2 como si fuera suyo
    // cuando en realidad lo está pidiendo).
    final juegosQueTiene = juegos
        .map((j) => Map<String, dynamic>.from(j as Map))
        .where((j) => j['intencion_pjg'] != 'busco')
        .toList();
    final juegosQueBusca = juegos
        .map((j) => Map<String, dynamic>.from(j as Map))
        .where((j) => j['intencion_pjg'] == 'busco')
        .toList();
    // La imagen grande ("como un post") solo sale si hay un juego
    // confirmado por Steam con carátula -- es la representación más
    // confiable. Si no hay ninguno verificado, se muestra en cambio una
    // fila de miniaturas de lo que sí tiene (antes esto quedaba oculto
    // por completo detrás de un juego elegido casi al azar).
    Map<String, dynamic>? heroConImagen;
    for (final j in juegosQueTiene) {
      final header = j['headerimg_jg'] as String?;
      if (j['origen_pjg'] == 'steam' && header != null && header.isNotEmpty) {
        heroConImagen = j;
        break;
      }
    }
    final portada = heroConImagen?['headerimg_jg'] as String?;
    final juegoParaGeneros =
        heroConImagen ??
        (juegosQueTiene.isNotEmpty ? juegosQueTiene.first : null);
    final generos = juegoParaGeneros != null
        ? ((juegoParaGeneros['generos_jg'] as List<dynamic>?) ?? [])
              .map((g) => g.toString())
              .toList()
        : <String>[];
    // El resto de lo que tiene, además del héroe -- solo tiene sentido
    // mostrarlo si el héroe ya "tapó" la vista con la imagen grande.
    final otrosQueTiene = heroConImagen != null
        ? juegosQueTiene.where((j) => j != heroConImagen).toList()
        : <Map<String, dynamic>>[];
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
              // ── Portada del juego (como un post con imagen) ─────────
              // Solo de juegos que el autor TIENE y confirma Steam -- ver
              // comentario arriba. Sin uno así, se cae a una fila de
              // miniaturas en vez de esconder por completo la oferta.
              if (portada != null && portada.isNotEmpty)
                AspectRatio(
                  aspectRatio: 16 / 7,
                  child: Image.network(
                    portada,
                    semanticLabel:
                        'Carátula de ${heroConImagen?['nom_jg'] ?? 'juego'}',
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        Container(color: SteamColors.bgCard),
                  ),
                )
              else if (juegosQueTiene.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      for (final j in juegosQueTiene.take(5)) ...[
                        MiniCaratula(
                          headerimg: j['headerimg_jg'] as String?,
                          nombre: j['nom_jg'] as String?,
                        ),
                        const SizedBox(width: 4),
                      ],
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Ofrece ${publicacion['total_juegos'] ?? juegosQueTiene.length} juego${juegosQueTiene.length == 1 ? '' : 's'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: SteamColors.textSec,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              // ── Resto de lo que tiene, si la imagen grande ya "tapó"
              // la vista de las demás (antes solo se veía un juego, sin
              // pista de que ofrecía más).
              if (otrosQueTiene.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Row(
                    children: [
                      for (final j in otrosQueTiene.take(4)) ...[
                        MiniCaratula(
                          headerimg: j['headerimg_jg'] as String?,
                          nombre: j['nom_jg'] as String?,
                        ),
                        const SizedBox(width: 4),
                      ],
                      if (otrosQueTiene.length > 4)
                        Text(
                          '+${otrosQueTiene.length - 4}',
                          style: const TextStyle(
                            color: SteamColors.textSec,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
              // ── Lo que busca -- nunca junto a lo que tiene, para no dar
              // a entender que ya lo posee (ej. "busca Spider-Man 2").
              if (juegosQueBusca.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.star_outline,
                        size: 14,
                        color: SteamColors.muted,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          'Busca: ${juegosQueBusca.map((j) => j['nom_jg'] ?? '').join(', ')}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: SteamColors.textSec,
                            fontSize: 12,
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
              // ── Pie: país + acción ───────────────────────────────────
              // El conteo de juegos ya se comunica arriba (imagen grande +
              // miniaturas / fila de miniaturas + "Ofrece N juegos"), no
              // hace falta repetirlo acá.
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Row(
                  children: [
                    Builder(
                      builder: (_) {
                        final codigo =
                            publicacion['paisfiltro_publi'] as String?;
                        final bandera = codigo != null && codigo.isNotEmpty
                            ? PaisUtil.codigoABandera(codigo)
                            : null;
                        if (bandera != null) {
                          return Text(
                            bandera,
                            style: const TextStyle(fontSize: 13),
                          );
                        }
                        return const Icon(
                          Icons.public,
                          size: 14,
                          color: SteamColors.muted,
                        );
                      },
                    ),
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
