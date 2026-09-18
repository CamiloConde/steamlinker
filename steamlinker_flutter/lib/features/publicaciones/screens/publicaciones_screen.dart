import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../widgets/desktop_body_width.dart';
import '../../../core/constants/pais_util.dart';
import '../../../core/constants/publicacion_constants.dart';
import '../../../core/refresh_signal.dart';
import '../../../core/utils/relacion_helper.dart';
import '../../../theme/colors.dart';
import '../../../theme/radii.dart';
import '../../../widgets/drop_field.dart';
import '../../../widgets/publicacion_card.dart';
import '../../../widgets/scroll_to_top_fab.dart';
import '../../../widgets/steam_app_bar.dart';
import '../../../widgets/steam_toast.dart';
import '../../amistad/providers/amistad_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../chat/providers/chat_provider.dart';
import '../../matches/providers/matches_provider.dart';
import '../../perfil/providers/perfil_provider.dart';
import '../providers/publicaciones_provider.dart';
import '../../usuarios/screens/usuario_detalle_screen.dart';
import 'crear_publicacion_screen.dart';
import 'publicacion_detalle_screen.dart';

/// Por debajo de este ancho se usa el layout móvil de una sola columna con
/// FAB. Igual al breakpoint de `ResponsiveShell` (no se importa de ahí para
/// evitar un ciclo de imports).
const _kEscritorio = 768.0;

class PublicacionesScreen extends StatefulWidget {
  /// true solo cuando `ResponsiveShell` la usa como pestaña de verdad del
  /// IndexedStack -- Navigator.canPop() daba falsos positivos en esta app
  /// (el router deja el stack raíz con más de una entrada incluso en el
  /// caso normal), así que se usa una señal explícita en vez de intentar
  /// adivinarlo. Bug real reportado por el usuario: refrescar/filtros
  /// duplicados en escritorio. Ver HANDOFF.md.
  final bool esPestana;

  const PublicacionesScreen({super.key, this.esPestana = false});

  @override
  State<PublicacionesScreen> createState() => _PublicacionesScreenState();
}

class _PublicacionesScreenState extends State<PublicacionesScreen> {
  bool _inicializado = false;
  final _scrollCtrl = ScrollController();

  // Conmutador de escritorio (wireframe turno 3b): "Familia" agrupa
  // busco_familia+busco_miembros, "Jugar ahora" es busco_companero, "Otro"
  // es el resto. Es un filtro puramente de cliente sobre la lista ya
  // cargada por PublicacionesProvider.buscar() — no pega otra vez al
  // backend, así los contadores de las 3 pestañas son siempre correctos.
  int _tabActivo = 0;

  int _tabDe(String? tipo) {
    if (tipo == 'busco_familia' || tipo == 'busco_miembros') return 0;
    if (tipo == 'busco_companero') return 1;
    return 2;
  }

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
      context.read<ChatProvider>().cargarConversaciones(),
    ]);
  }

  @override
  void initState() {
    super.initState();
    refreshSignal.addListener(_onRefreshSignal);
  }

  @override
  void dispose() {
    refreshSignal.removeListener(_onRefreshSignal);
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onRefreshSignal() {
    if (refreshSignal.indice == 2) _recargar();
  }

  Future<void> _recargar() async {
    await context.read<PublicacionesProvider>().buscar();
  }

  Future<void> _abrirFiltros({bool ocultarTipo = false}) async {
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
                    if (!ocultarTipo)
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

    final feed = Column(
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
    );

    final esEscritorio = MediaQuery.of(context).size.width >= _kEscritorio;

    if (esEscritorio) {
      final publicaciones = publicacionesProv.publicaciones;
      final conteos = [0, 0, 0];
      for (final p in publicaciones) {
        conteos[_tabDe(p['tipo_publi'] as String?)]++;
      }
      final filaFiltradas = publicaciones
          .where((p) => _tabDe(p['tipo_publi'] as String?) == _tabActivo)
          .toList();

      return Scaffold(
        backgroundColor: SteamColors.bgDeep,
        // En escritorio la barra global de ResponsiveShell ya trae el
        // refrescar único; el filtro se movió a la fila de pestañas de
        // abajo (_ConmutadorTabs.trailing) en vez de flotar solo en una
        // barra propia sin título. Solo se omite del todo cuando esta
        // pantalla es una pestaña de verdad.
        appBar: widget.esPestana
            ? null
            : SteamAppBar(
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
                    onPressed: () => _abrirFiltros(ocultarTipo: true),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: SteamColors.blue),
                    tooltip: 'Actualizar',
                    onPressed: _recargar,
                  ),
                ],
              ),
        body: DesktopBodyWidth(
          maxWidth: 760,
          child: Column(
            children: [
              _ConmutadorTabs(
                activo: _tabActivo,
                conteos: conteos,
                onTab: (i) => setState(() => _tabActivo = i),
                trailing: IconButton(
                  icon: Icon(
                    Icons.tune_rounded,
                    color: publicacionesProv.tieneFiltrosActivos
                        ? SteamColors.blue
                        : SteamColors.muted,
                  ),
                  tooltip: 'Filtros',
                  onPressed: () => _abrirFiltros(ocultarTipo: true),
                ),
              ),
              _ComposerConmutador(
                tab: _tabActivo,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CrearPublicacionScreen()),
                ),
              ),
              if (publicacionesProv.tieneFiltrosActivos)
                _FiltrosActivosBar(
                  prov: publicacionesProv,
                  onEditar: () => _abrirFiltros(ocultarTipo: true),
                  onLimpiar: () => publicacionesProv.limpiarFiltros(),
                ),
              Expanded(
                child: RefreshIndicator(
                  color: SteamColors.blue,
                  backgroundColor: SteamColors.bgDeep,
                  onRefresh: _recargar,
                  // Antes esto era _TablaPublicaciones, una tabla densa
                  // (TIPO/USUARIO/CUPOS/REP/HACE). El usuario comparó
                  // contra el wireframe y contra Descubrir (que ya pasó
                  // de tabla a tarjeta rica antes, por el mismo pedido) y
                  // pidió lo mismo acá. En vez de diseñar una tarjeta
                  // nueva, se reutiliza PublicacionCard -- ya existía y
                  // ya se usaba en móvil, con avatar+autor+reputación,
                  // título, descripción, portada del juego y país. Ver
                  // HANDOFF.md.
                  child: _buildLista(
                    publicacionesProv,
                    auth,
                    matchesProv,
                    amistadProv,
                    auth.usuario?['id'] as int?,
                    filas: filaFiltradas,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

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
      body: DesktopBodyWidth(
        child: SafeArea(
          child: Stack(
            children: [
              feed,
              ScrollToTopFab(controller: _scrollCtrl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLista(
    PublicacionesProvider publicacionesProv,
    AuthProvider auth,
    MatchesProvider matchesProv,
    AmistadProvider amistadProv,
    int? miId, {
    List<dynamic>? filas,
  }) {
    final lista = filas ?? publicacionesProv.publicaciones;

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

    if (lista.isEmpty) {
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
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
      itemCount: lista.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final publicacion = lista[index];
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
                    showSteamToast(context, publicacionesProv.error!, SteamColors.red);
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

/// Conmutador "FAMILIA / JUGAR AHORA / OTRO" (wireframe turno 3, opción
/// 3b): mapea 1:1 con tipo_publi y reemplaza los accesos rápidos por tipo
/// que antes vivían en una columna lateral aparte.
class _ConmutadorTabs extends StatelessWidget {
  final int activo;
  final List<int> conteos;
  final ValueChanged<int> onTab;
  final Widget? trailing;

  static const _etiquetas = ['FAMILIA', 'JUGAR AHORA', 'OTRO'];

  const _ConmutadorTabs({
    required this.activo,
    required this.conteos,
    required this.onTab,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: SteamColors.bgPanel,
        border: Border(bottom: BorderSide(color: SteamColors.border)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < _etiquetas.length; i++)
            _TabItem(
              label: _etiquetas[i],
              contador: conteos[i],
              activo: activo == i,
              onTap: () => onTab(i),
            ),
          if (trailing != null) ...[const Spacer(), trailing!],
        ],
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  final String label;
  final int contador;
  final bool activo;
  final VoidCallback onTap;

  const _TabItem({
    required this.label,
    required this.contador,
    required this.activo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 22),
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: activo ? SteamColors.blue : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                  color: activo ? SteamColors.blue : SteamColors.textSec,
                ),
              ),
              TextSpan(
                text: '  $contador',
                style: const TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  color: SteamColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Barra de composición contextual: el texto y el botón cambian según la
/// pestaña activa, en vez de un genérico "Comparte algo..." para todo.
class _ComposerConmutador extends StatelessWidget {
  final int tab;
  final VoidCallback onTap;

  const _ComposerConmutador({required this.tab, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const textos = [
      'Publica tu cupo o tu búsqueda de familia',
      'Publica que quieres jugar ahora',
      'Comparte algo con la comunidad',
    ];
    const botones = ['Publicar en Familia', 'Publicar partida', 'Publicar'];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: SteamColors.bgCard,
        borderRadius: BorderRadius.circular(SteamRadii.sm),
        border: Border.all(color: SteamColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              textos[tab],
              style: const TextStyle(color: SteamColors.textSec, fontSize: 13),
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(SteamRadii.sm),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                decoration: BoxDecoration(
                  color: SteamColors.blue,
                  borderRadius: BorderRadius.circular(SteamRadii.sm),
                ),
                child: Text(
                  botones[tab],
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

