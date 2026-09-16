import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../widgets/desktop_body_width.dart';
import '../../../core/constants/pais_util.dart';
import '../../../core/constants/publicacion_constants.dart';
import '../../../core/utils/relacion_helper.dart';
import '../../../theme/colors.dart';
import '../../../widgets/drop_field.dart';
import '../../../widgets/publicacion_card.dart';
import '../../../widgets/steam_app_bar.dart';
import '../../amistad/providers/amistad_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../matches/providers/matches_provider.dart';
import '../../perfil/providers/perfil_provider.dart';
import '../providers/publicaciones_provider.dart';
import '../../usuarios/screens/usuario_detalle_screen.dart';
import 'crear_publicacion_screen.dart';
import 'publicacion_detalle_screen.dart';

class PublicacionesScreen extends StatefulWidget {
  const PublicacionesScreen({super.key});

  @override
  State<PublicacionesScreen> createState() => _PublicacionesScreenState();
}

class _PublicacionesScreenState extends State<PublicacionesScreen> {
  bool _inicializado = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_inicializado) {
      _inicializado = true;
      _inicializar();
    }
  }

  Future<void> _inicializar() async {
    final auth = context.read<AuthProvider>();
    final perfil = context.read<PerfilProvider>();
    final id = auth.usuario?['id'];
    if (id != null && perfil.juegos.isEmpty) {
      await perfil.cargarPerfil(id);
    }
    if (!mounted) return;
    await Future.wait([
      context.read<PublicacionesProvider>().buscar(),
      context.read<MatchesProvider>().cargarTodo(),
      context.read<AmistadProvider>().cargarTodo(),
    ]);
  }

  Future<void> _recargar() async {
    await context.read<PublicacionesProvider>().buscar();
  }

  Future<void> _abrirFiltros() async {
    final prov = context.read<PublicacionesProvider>();
    final perfil = context.read<PerfilProvider>();

    var tipoEtiqueta = PublicacionConstants.tiposFiltroEtiquetas.first;
    if (prov.filtroTipo != null && prov.filtroTipo!.isNotEmpty) {
      for (var i = 0; i < PublicacionConstants.tiposFiltroValores.length; i++) {
        if (PublicacionConstants.tiposFiltroValores[i] == prov.filtroTipo) {
          tipoEtiqueta = PublicacionConstants.tiposFiltroEtiquetas[i];
          break;
        }
      }
    }
    var paisEtiqueta = prov.filtroPais == null || prov.filtroPais!.isEmpty
        ? PaisUtil.todos
        : PaisUtil.codigoANombre(prov.filtroPais);
    var juegoEtiqueta = prov.filtroJuegoNombre ?? 'Todos los juegos';
    var ordenEtiqueta = prov.filtroOrden == PublicacionConstants.ordenReputacion
        ? 'Mayor reputación'
        : 'Más recientes';

    final juegosFiltro = [
      'Todos los juegos',
      ...perfil.juegos.map((j) => j['nombre']?.toString() ?? 'Juego'),
    ];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: SteamColors.bgPanel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Filtros',
                          style: TextStyle(
                            color: SteamColors.light,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close, color: SteamColors.muted),
                          tooltip: 'Cerrar',
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    DropField(
                      label: 'Tipo',
                      value: tipoEtiqueta,
                      items: PublicacionConstants.tiposFiltroEtiquetas,
                      onChanged: (v) => setSheetState(() => tipoEtiqueta = v),
                    ),
                    DropField(
                      label: 'País',
                      value: paisEtiqueta,
                      items: [PaisUtil.todos, ...PaisUtil.nombres],
                      onChanged: (v) => setSheetState(() => paisEtiqueta = v),
                    ),
                    DropField(
                      label: 'Juego',
                      value: juegoEtiqueta,
                      items: juegosFiltro,
                      onChanged: (v) => setSheetState(() => juegoEtiqueta = v),
                    ),
                    DropField(
                      label: 'Orden',
                      value: ordenEtiqueta,
                      items: const ['Más recientes', 'Mayor reputación'],
                      onChanged: (v) => setSheetState(() => ordenEtiqueta = v),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              Navigator.pop(context);
                              await prov.limpiarFiltros();
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: SteamColors.muted,
                              side: const BorderSide(color: SteamColors.border),
                            ),
                            child: const Text('Limpiar'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              final tipoVal =
                                  PublicacionConstants.valorTipoFiltro(tipoEtiqueta);
                              final paisVal = paisEtiqueta == PaisUtil.todos
                                  ? null
                                  : PaisUtil.nombreACodigo(paisEtiqueta);

                              int? appid;
                              String? juegoNombre;
                              if (juegoEtiqueta != 'Todos los juegos') {
                                for (final j in perfil.juegos) {
                                  if ((j['nombre']?.toString() ?? '') == juegoEtiqueta) {
                                    appid = j['appid'] as int?;
                                    juegoNombre = juegoEtiqueta;
                                    break;
                                  }
                                }
                              }

                              final orden = ordenEtiqueta == 'Mayor reputación'
                                  ? PublicacionConstants.ordenReputacion
                                  : PublicacionConstants.ordenRecientes;

                              Navigator.pop(context);
                              await prov.setFiltros(
                                tipo: tipoVal.isEmpty ? null : tipoVal,
                                pais: paisVal,
                                appid: appid,
                                juegoNombre: juegoNombre,
                                orden: orden,
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: SteamColors.blue,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Aplicar'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final publicacionesProv = context.watch<PublicacionesProvider>();
    final auth = context.watch<AuthProvider>();
    final matchesProv = context.watch<MatchesProvider>();
    final amistadProv = context.watch<AmistadProvider>();

    return Scaffold(
      backgroundColor: SteamColors.bgDeep,
      appBar: SteamAppBar(
        title: 'PUBLICACIONES',
        actions: [
          IconButton(
            icon: Icon(
              Icons.tune_rounded,
              color: publicacionesProv.tieneFiltrosActivos
                  ? SteamColors.blue
                  : SteamColors.muted,
            ),
            tooltip: 'Filtros',
            onPressed: _abrirFiltros,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: SteamColors.blue),
            tooltip: 'Actualizar',
            onPressed: _recargar,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CrearPublicacionScreen()),
          );
        },
        backgroundColor: SteamColors.blue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text(
          'Crear',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: DesktopBodyWidth(child: SafeArea(
        child: Column(
          children: [
            if (publicacionesProv.tieneFiltrosActivos)
              _FiltrosActivosBar(
                prov: publicacionesProv,
                onEditar: _abrirFiltros,
                onLimpiar: () => publicacionesProv.limpiarFiltros(),
              ),
            Expanded(
              child: RefreshIndicator(
                color: SteamColors.blue,
                backgroundColor: SteamColors.bgDeep,
                onRefresh: _recargar,
                child: _buildLista(
                  publicacionesProv,
                  auth,
                  matchesProv,
                  amistadProv,
                  auth.usuario?['id'] as int?,
                ),
              ),
            ),
          ],
        ),
      )),
    );
  }

  Widget _buildLista(
    PublicacionesProvider publicacionesProv,
    AuthProvider auth,
    MatchesProvider matchesProv,
    AmistadProvider amistadProv,
    int? miId,
  ) {
    if (publicacionesProv.cargando) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation(SteamColors.blue),
        ),
      );
    }

    if (publicacionesProv.error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            publicacionesProv.error!,
            style: const TextStyle(color: Colors.red),
          ),
        ],
      );
    }

    if (publicacionesProv.publicaciones.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 40),
          Center(
            child: Text(
              publicacionesProv.tieneFiltrosActivos
                  ? 'No hay publicaciones con estos filtros.'
                  : 'No hay publicaciones disponibles.',
              style: const TextStyle(color: SteamColors.textSec),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
      itemCount: publicacionesProv.publicaciones.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final publicacion = publicacionesProv.publicaciones[index];
        final autorId = publicacion['id_usu'] as int?;
        final esMia = miId != null && miId == autorId;
        final relacion = RelacionResumen.paraUsuario(
          miId: miId,
          otroId: autorId,
          matches: matchesProv,
          amistad: amistadProv,
        );

        return PublicacionCard(
          publicacion: Map<String, dynamic>.from(publicacion as Map),
          esMia: esMia,
          relacion: relacion,
          onTap: () async {
            final id = publicacion['id_publi'] as int?;
            if (id == null) return;
            final actualizado = await Navigator.of(context).push<bool>(
              MaterialPageRoute(
                builder: (_) => PublicacionDetalleScreen(idPubli: id),
              ),
            );
            if (actualizado == true && context.mounted) {
              await _recargar();
            }
          },
          onTapAutor: autorId != null
              ? () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => UsuarioDetalleScreen(
                        userId: autorId,
                        idPubli: publicacion['id_publi'] as int?,
                        tituloPublicacion: publicacion['titulo_publi'] as String?,
                      ),
                    ),
                  );
                }
              : null,
          onCerrar: esMia
              ? () async {
                  await publicacionesProv.cerrar(publicacion['id_publi']);
                  if (!context.mounted) return;
                  if (publicacionesProv.error != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(publicacionesProv.error!)),
                    );
                  }
                }
              : null,
        );
      },
    );
  }
}

class _FiltrosActivosBar extends StatelessWidget {
  final PublicacionesProvider prov;
  final VoidCallback onEditar;
  final VoidCallback onLimpiar;

  const _FiltrosActivosBar({
    required this.prov,
    required this.onEditar,
    required this.onLimpiar,
  });

  @override
  Widget build(BuildContext context) {
    final chips = <String>[];
    if (prov.filtroTipo != null && prov.filtroTipo!.isNotEmpty) {
      chips.add(PublicacionConstants.etiquetaTipo(prov.filtroTipo));
    }
    if (prov.filtroPais != null && prov.filtroPais!.isNotEmpty) {
      chips.add(PaisUtil.codigoANombre(prov.filtroPais));
    }
    if (prov.filtroJuegoNombre != null) {
      chips.add(prov.filtroJuegoNombre!);
    }
    if (prov.filtroOrden == PublicacionConstants.ordenReputacion) {
      chips.add('Por reputación');
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: SteamColors.bgPanel,
        border: Border(bottom: BorderSide(color: SteamColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: chips
                    .map(
                      (c) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Chip(
                          label: Text(c, style: const TextStyle(fontSize: 11)),
                          backgroundColor: SteamColors.bgCard,
                          labelStyle: const TextStyle(color: SteamColors.blue),
                          side: const BorderSide(color: SteamColors.border),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
          TextButton(onPressed: onEditar, child: const Text('Editar')),
          IconButton(
            icon: const Icon(Icons.clear, size: 18, color: SteamColors.muted),
            tooltip: 'Quitar filtros',
            onPressed: onLimpiar,
          ),
        ],
      ),
    );
  }
}

