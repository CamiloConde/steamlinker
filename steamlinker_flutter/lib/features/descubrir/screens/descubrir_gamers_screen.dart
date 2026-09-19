import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/pais_util.dart';
import '../../../core/constants/publicacion_constants.dart';
import '../../../core/refresh_signal.dart';
import '../../../theme/colors.dart';
import '../../../theme/radii.dart';
import '../../../widgets/desktop_body_width.dart';
import '../../../widgets/drop_field.dart';
import '../../../widgets/pais_selector_field.dart';
import '../../../widgets/scroll_to_top_fab.dart';
import '../../../widgets/steam_app_bar.dart';
import '../../../widgets/usuario_card.dart';
import '../../auth/providers/auth_provider.dart';
import '../../matches/screens/matches_screen.dart';
import '../../perfil/providers/perfil_provider.dart';
import '../../usuarios/screens/usuario_detalle_screen.dart';

/// Por debajo de este ancho se usa el feed móvil de tarjetas de siempre.
/// Igual al breakpoint de `ResponsiveShell`.
const _kEscritorio = 768.0;

enum _Orden { enComun, reputacion, reciente }

class DescubrirGamersScreen extends StatefulWidget {
  /// Búsqueda disparada desde el buscador de la barra superior del sidebar
  /// de escritorio (ver `ResponsiveShell`). En móvil siempre llega vacía —
  /// esa pantalla usa su propio buscador interno.
  final String busquedaExterna;

  /// Filtro por juego disparado desde "Tus juegos" en el sidebar de
  /// escritorio: un clic en un juego de la lista te trae directo aquí ya
  /// filtrado por ese juego, en vez de ser solo una lista decorativa.
  final int? filtroAppidExterno;
  final String? filtroJuegoNombreExterno;

  /// true solo cuando `ResponsiveShell` la usa como pestaña de verdad del
  /// IndexedStack -- Navigator.canPop() daba falsos positivos en esta app
  /// (el router deja el stack raíz con más de una entrada incluso en el
  /// caso normal), así que se usa una señal explícita en vez de intentar
  /// adivinarlo. Bug real reportado por el usuario: refrescar/filtros
  /// duplicados en escritorio. Ver HANDOFF.md.
  final bool esPestana;

  const DescubrirGamersScreen({
    super.key,
    this.busquedaExterna = '',
    this.filtroAppidExterno,
    this.filtroJuegoNombreExterno,
    this.esPestana = false,
  });

  @override
  State<DescubrirGamersScreen> createState() => _DescubrirGamersScreenState();
}

class _DescubrirGamersScreenState extends State<DescubrirGamersScreen> {
  bool _inicializado = false;
  String? _filtroJuegoNombre;
  int? _filtroAppid;
  String? _filtroTipoEtiqueta;
  String? _filtroPaisEtiqueta;
  int _minEnComun = 0;
  _Orden _orden = _Orden.enComun;
  String _busqueda = '';
  final _busquedaCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_inicializado) {
      _inicializado = true;
      _busqueda = widget.busquedaExterna;
      _busquedaCtrl.text = _busqueda;
      if (widget.filtroAppidExterno != null) {
        _filtroAppid = widget.filtroAppidExterno;
        _filtroJuegoNombre = widget.filtroJuegoNombreExterno;
      }
      _inicializar();
    }
  }

  @override
  void didUpdateWidget(DescubrirGamersScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.busquedaExterna != oldWidget.busquedaExterna &&
        widget.busquedaExterna.isNotEmpty) {
      setState(() => _busqueda = widget.busquedaExterna);
      _busquedaCtrl.text = _busqueda;
      _busquedaCtrl.selection = TextSelection.collapsed(offset: _busqueda.length);
    }
    if (widget.filtroAppidExterno != null &&
        widget.filtroAppidExterno != oldWidget.filtroAppidExterno) {
      setState(() {
        _filtroAppid = widget.filtroAppidExterno;
        _filtroJuegoNombre = widget.filtroJuegoNombreExterno;
        // El filtro por appid es server-side (_recargar lo manda como
        // query param) -- guardarlo en el estado local sin volver a pedir
        // la lista no cambiaba nada en pantalla. Se resetean los demás
        // filtros porque este clic viene con una intención nueva y
        // puntual ("gente que juega ESTO"), no debería arrastrar un
        // filtro de tipo/país que haya quedado de antes.
        _filtroTipoEtiqueta = null;
        _filtroPaisEtiqueta = null;
        _minEnComun = 0;
      });
      _recargar();
    }
  }

  @override
  void initState() {
    super.initState();
    refreshSignal.addListener(_onRefreshSignal);
  }

  @override
  void dispose() {
    refreshSignal.removeListener(_onRefreshSignal);
    _busquedaCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onRefreshSignal() {
    if (refreshSignal.indice == 1) _recargar();
  }

  Future<void> _inicializar() async {
    final auth = context.read<AuthProvider>();
    final perfil = context.read<PerfilProvider>();
    final id = auth.usuario?['id'];
    if (id != null && perfil.juegos.isEmpty) {
      await perfil.cargarPerfil(id);
    }
    if (!mounted) return;
    await perfil.descubrirUsuarios(appid: _filtroAppid);
  }

  Future<void> _recargar() async {
    await context.read<PerfilProvider>().descubrirUsuarios(
      appid: _filtroAppid,
    );
  }

  Future<void> _abrirFiltros() async {
    final perfil = context.read<PerfilProvider>();
    var tipoEtiqueta =
        _filtroTipoEtiqueta ?? PublicacionConstants.tiposFiltroEtiquetas.first;
    var paisEtiqueta = _filtroPaisEtiqueta ?? PaisUtil.todos;
    var juegoEtiqueta = _filtroJuegoNombre ?? 'Todos los juegos';

    // DropdownButton exige valores únicos por item (si dos juegos comparten
    // nombre, el widget queda en un estado inconsistente: en debug lanza un
    // assert, y en el build de release ese assert se descarta silenciosamente,
    // dejando el dropdown sin poder seleccionar nada). Se deduplica por nombre.
    final nombresVistos = <String>{};
    final juegosFiltro = <String>['Todos los juegos'];
    for (final j in perfil.juegos) {
      final nombre = j['nombre']?.toString();
      if (nombre != null && nombre.isNotEmpty && nombresVistos.add(nombre)) {
        juegosFiltro.add(nombre);
      }
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: SteamColors.bgPanel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Filtros de búsqueda',
                    style: TextStyle(
                      color: SteamColors.light,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  DropField(
                    label: 'Tipo de publicación',
                    value: tipoEtiqueta,
                    items: PublicacionConstants.tiposFiltroEtiquetas,
                    onChanged: (v) => setSheetState(() => tipoEtiqueta = v),
                  ),
                  PaisSelectorField(
                    label: 'País',
                    value: paisEtiqueta,
                    items: [PaisUtil.todos, ...PaisUtil.nombres],
                    onChanged: (v) => setSheetState(() => paisEtiqueta = v),
                  ),
                  DropField(
                    label: 'Juego en publicación',
                    value: juegoEtiqueta,
                    items: juegosFiltro,
                    onChanged: (v) => setSheetState(() => juegoEtiqueta = v),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SteamColors.blue,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      final tipo = PublicacionConstants.valorTipoFiltro(tipoEtiqueta);
                      final pais = paisEtiqueta == PaisUtil.todos
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

                      setState(() {
                        _filtroAppid = appid;
                        _filtroJuegoNombre = juegoNombre;
                        _filtroTipoEtiqueta = tipoEtiqueta ==
                                PublicacionConstants.tiposFiltroEtiquetas.first
                            ? null
                            : tipoEtiqueta;
                        _filtroPaisEtiqueta =
                            paisEtiqueta == PaisUtil.todos ? null : paisEtiqueta;
                      });

                      Navigator.pop(context);
                      perfil.descubrirUsuarios(
                        tipo: tipo.isEmpty ? null : tipo,
                        pais: pais,
                        appid: appid,
                      );
                    },
                    child: const Text('Aplicar'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _abrirUsuario(Map<String, dynamic> usuario) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UsuarioDetalleScreen(
          userId: usuario['id_usu'] as int,
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _baseFiltrada(PerfilProvider perfilProv, int? miId) {
    return perfilProv.usuariosDescubrir
        .where((u) => miId == null || (u as Map)['id_usu'] != miId)
        .map((u) => Map<String, dynamic>.from(u as Map))
        .toList();
  }

  List<Map<String, dynamic>> _listaFiltrada(List<Map<String, dynamic>> base) {
    final q = _busqueda.trim().toLowerCase();
    var lista = base
        .where((u) => q.isEmpty ||
            (u['username_usu']?.toString().toLowerCase() ?? '').contains(q))
        .where((u) => (u['juegos_en_comun'] as int? ?? 0) >= _minEnComun)
        .toList();

    switch (_orden) {
      case _Orden.enComun:
        lista.sort((a, b) => (b['juegos_en_comun'] as int? ?? 0)
            .compareTo(a['juegos_en_comun'] as int? ?? 0));
        break;
      case _Orden.reputacion:
        lista.sort((a, b) => (double.tryParse('${b['repu_usu']}') ?? 0)
            .compareTo(double.tryParse('${a['repu_usu']}') ?? 0));
        break;
      case _Orden.reciente:
        lista.sort((a, b) {
          final da = DateTime.tryParse('${a['ultima_publicacion']}');
          final db = DateTime.tryParse('${b['ultima_publicacion']}');
          if (da == null || db == null) return 0;
          return db.compareTo(da);
        });
        break;
    }
    return lista;
  }

  @override
  Widget build(BuildContext context) {
    final perfilProv = context.watch<PerfilProvider>();
    final auth = context.watch<AuthProvider>();
    final miId = auth.usuario?['id'];
    final esEscritorio = MediaQuery.of(context).size.width >= _kEscritorio;

    final filtrosActivos = _filtroTipoEtiqueta != null ||
        _filtroPaisEtiqueta != null ||
        _filtroJuegoNombre != null;

    final base = _baseFiltrada(perfilProv, miId);
    final lista = _listaFiltrada(base);

    return Scaffold(
      backgroundColor: SteamColors.bgDeep,
      // En escritorio la barra global de ResponsiveShell ya trae el
      // refrescar único; "Mis solicitudes" se movió dentro del cuerpo de
      // escritorio (ver _CuerpoEscritorio) en vez de flotar solo en una
      // barra propia sin título. El filtro (tune) ya estaba oculto en
      // escritorio de antes -- el panel lateral lo cubre. Se elimina del
      // todo solo cuando esta pantalla es una pestaña de verdad.
      appBar: (esEscritorio && widget.esPestana)
          ? null
          : SteamAppBar(
              title: 'DESCUBRIR',
              actions: [
                IconButton(
                  icon: const Icon(Icons.inbox_outlined, color: SteamColors.muted),
                  tooltip: 'Mis solicitudes',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const MatchesScreen()),
                    );
                  },
                ),
                IconButton(
                  icon: Icon(
                    Icons.tune_rounded,
                    color: filtrosActivos ? SteamColors.blue : SteamColors.muted,
                  ),
                  tooltip: 'Filtros de publicación',
                  onPressed: _abrirFiltros,
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: SteamColors.blue),
                  tooltip: 'Actualizar',
                  onPressed: _recargar,
                ),
              ],
            ),
      body: Stack(
        children: [
          esEscritorio
          ? _CuerpoEscritorio(
              cargando: perfilProv.descubrirCargando,
              base: base,
              lista: lista,
              busquedaCtrl: _busquedaCtrl,
              onBusqueda: (v) => setState(() => _busqueda = v),
              orden: _orden,
              onOrden: (v) => setState(() => _orden = v),
              filtroJuegoNombre: _filtroJuegoNombre,
              filtroPaisEtiqueta: _filtroPaisEtiqueta,
              filtroTipoEtiqueta: _filtroTipoEtiqueta,
              minEnComun: _minEnComun,
              onMinEnComun: (v) => setState(() => _minEnComun = v),
              onAbrirFiltros: _abrirFiltros,
              onLimpiarFiltros: () {
                setState(() {
                  _filtroAppid = null;
                  _filtroJuegoNombre = null;
                  _filtroTipoEtiqueta = null;
                  _filtroPaisEtiqueta = null;
                  _minEnComun = 0;
                });
                perfilProv.descubrirUsuarios();
              },
              onRecargar: _recargar,
              onMisSolicitudes: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const MatchesScreen()),
                );
              },
              onTap: _abrirUsuario,
            )
          // DesktopBodyWidth NO envuelve esta rama porque el contenido
          // incluye un ListView (_ListaGamers) -- envolverlo angosta el
          // Scrollable mismo, no solo lo que se ve, y el scroll con rueda
          // deja de responder fuera de esa franja angosta (bug real
          // reportado por el usuario). El margen se calcula acá y se pasa
          // como extra de padding al ListView. Ver desktop_body_width.dart.
          : LayoutBuilder(
              builder: (context, constraints) {
                final margen = DesktopBodyWidth.margenHorizontal(constraints.maxWidth, 720);
                return Column(
                children: [
                  if (filtrosActivos)
                    Container(
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
                                children: [
                                  if (_filtroTipoEtiqueta != null)
                                    _chipFiltro(_filtroTipoEtiqueta!),
                                  if (_filtroPaisEtiqueta != null)
                                    _chipFiltro(_filtroPaisEtiqueta!),
                                  if (_filtroJuegoNombre != null)
                                    _chipFiltro(_filtroJuegoNombre!),
                                ],
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _filtroAppid = null;
                                _filtroJuegoNombre = null;
                                _filtroTipoEtiqueta = null;
                                _filtroPaisEtiqueta = null;
                              });
                              perfilProv.descubrirUsuarios();
                            },
                            child: const Text('Limpiar', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: RefreshIndicator(
                      color: SteamColors.blue,
                      onRefresh: _recargar,
                      child: perfilProv.descubrirCargando
                          ? const Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation(SteamColors.blue),
                              ),
                            )
                          : _ListaGamers(
                              usuarios: lista,
                              onTap: _abrirUsuario,
                              controller: _scrollCtrl,
                              margenExtra: margen,
                            ),
                    ),
                  ),
                ],
                );
              },
            ),
          ScrollToTopFab(controller: _scrollCtrl),
        ],
      ),
    );
  }

  Widget _chipFiltro(String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Chip(
        label: Text(label, style: const TextStyle(fontSize: 11)),
        backgroundColor: SteamColors.bgCard,
        labelStyle: const TextStyle(color: SteamColors.blue),
        side: const BorderSide(color: SteamColors.border),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _ListaGamers extends StatelessWidget {
  final List<Map<String, dynamic>> usuarios;
  final ValueChanged<Map<String, dynamic>> onTap;
  final ScrollController? controller;
  final double margenExtra;

  const _ListaGamers({
    required this.usuarios,
    required this.onTap,
    this.controller,
    this.margenExtra = 0,
  });

  @override
  Widget build(BuildContext context) {
    if (usuarios.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 48),
          Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'No hay gamers con publicaciones activas.\nPrueba otros filtros o vuelve más tarde.',
                textAlign: TextAlign.center,
                style: TextStyle(color: SteamColors.textSec),
              ),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      controller: controller,
      padding: EdgeInsets.symmetric(horizontal: 16 + margenExtra, vertical: 16),
      itemCount: usuarios.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final u = usuarios[index];
        final total = u['total_publicaciones'] ?? 0;
        return UsuarioCard(
          usuario: u,
          subtitulo: u['descrip_usu']?.toString().isNotEmpty == true
              ? u['descrip_usu']
              : '$total publicación${total == 1 ? '' : 'es'} activa${total == 1 ? '' : 's'}',
          onTap: () => onTap(u),
        );
      },
    );
  }
}

/// Cuerpo de escritorio (referencia visual mandada por el usuario, ver
/// HANDOFF.md): lista de tarjetas ricas a la izquierda + panel de filtros
/// y estadísticas a la derecha, en vez de la tabla densa que había antes —
/// el usuario probó la tabla y prefirió esta densidad de tarjeta.
class _CuerpoEscritorio extends StatelessWidget {
  final bool cargando;
  final List<Map<String, dynamic>> base;
  final List<Map<String, dynamic>> lista;
  final TextEditingController busquedaCtrl;
  final ValueChanged<String> onBusqueda;
  final _Orden orden;
  final ValueChanged<_Orden> onOrden;
  final String? filtroJuegoNombre;
  final String? filtroPaisEtiqueta;
  final String? filtroTipoEtiqueta;
  final int minEnComun;
  final ValueChanged<int> onMinEnComun;
  final VoidCallback onAbrirFiltros;
  final VoidCallback onLimpiarFiltros;
  final Future<void> Function() onRecargar;
  final ValueChanged<Map<String, dynamic>> onTap;
  final VoidCallback onMisSolicitudes;

  const _CuerpoEscritorio({
    required this.cargando,
    required this.base,
    required this.lista,
    required this.busquedaCtrl,
    required this.onBusqueda,
    required this.orden,
    required this.onOrden,
    required this.filtroJuegoNombre,
    required this.filtroPaisEtiqueta,
    required this.filtroTipoEtiqueta,
    required this.minEnComun,
    required this.onMinEnComun,
    required this.onAbrirFiltros,
    required this.onLimpiarFiltros,
    required this.onRecargar,
    required this.onTap,
    required this.onMisSolicitudes,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Descubrir',
                      style: TextStyle(color: SteamColors.light, fontSize: 24, fontWeight: FontWeight.w800),
                    ),
                    const Spacer(),
                    OutlinedButton.icon(
                      onPressed: onMisSolicitudes,
                      icon: const Icon(Icons.inbox_outlined, size: 16, color: SteamColors.muted),
                      label: const Text('Mis solicitudes', style: TextStyle(fontSize: 12.5)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: SteamColors.textSec,
                        side: const BorderSide(color: SteamColors.border),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Jugadores buscando compañía',
                            style: TextStyle(color: SteamColors.light, fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Personas reales que quieren jugar ahora mismo.',
                            style: TextStyle(color: SteamColors.textSec, fontSize: 12.5),
                          ),
                        ],
                      ),
                    ),
                    _OrdenDropdown(orden: orden, onChanged: onOrden),
                  ],
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: cargando
                      ? const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation(SteamColors.blue),
                          ),
                        )
                      : RefreshIndicator(
                          color: SteamColors.blue,
                          onRefresh: onRecargar,
                          child: lista.isEmpty
                              ? ListView(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  children: const [
                                    SizedBox(height: 60),
                                    Center(
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 24),
                                        child: Text(
                                          'No hay gamers que coincidan con estos filtros.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(color: SteamColors.textSec),
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : ListView.separated(
                                  itemCount: lista.length,
                                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                                  itemBuilder: (context, i) => _TarjetaGamer(
                                    usuario: lista[i],
                                    onTap: () => onTap(lista[i]),
                                  ),
                                ),
                        ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(
          width: 280,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 16, 20, 16),
            child: _PanelLateral(
              busquedaCtrl: busquedaCtrl,
              onBusqueda: onBusqueda,
              filtroJuegoNombre: filtroJuegoNombre,
              filtroPaisEtiqueta: filtroPaisEtiqueta,
              filtroTipoEtiqueta: filtroTipoEtiqueta,
              minEnComun: minEnComun,
              onMinEnComun: onMinEnComun,
              onAbrirFiltros: onAbrirFiltros,
              onLimpiarFiltros: onLimpiarFiltros,
              base: base,
            ),
          ),
        ),
      ],
    );
  }
}

class _OrdenDropdown extends StatelessWidget {
  final _Orden orden;
  final ValueChanged<_Orden> onChanged;

  const _OrdenDropdown({required this.orden, required this.onChanged});

  static const _etiquetas = {
    _Orden.enComun: 'Más en común',
    _Orden.reputacion: 'Mayor reputación',
    _Orden.reciente: 'Más recientes',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: SteamColors.bgInput,
        borderRadius: BorderRadius.circular(SteamRadii.sm),
        border: Border.all(color: SteamColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<_Orden>(
          value: orden,
          isDense: true,
          dropdownColor: SteamColors.bgCard,
          style: const TextStyle(color: SteamColors.light, fontSize: 12.5),
          icon: const Icon(Icons.expand_more, color: SteamColors.muted, size: 18),
          items: _Orden.values
              .map((o) => DropdownMenuItem(value: o, child: Text(_etiquetas[o]!)))
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}

/// Tarjeta rica de jugador: avatar, país, bio, etiqueta de tipo de
/// publicación, juegos en común (carátulas reales) y el juego de su
/// publicación más reciente con horas jugadas si las tiene registradas.
/// Nada de "en línea" falso ni géneros/idiomas inventados — ver HANDOFF.md.
class _TarjetaGamer extends StatelessWidget {
  final Map<String, dynamic> usuario;
  final VoidCallback onTap;

  const _TarjetaGamer({required this.usuario, required this.onTap});

  static String _hace(dynamic fecha) {
    if (fecha == null) return '';
    final dt = fecha is String ? DateTime.tryParse(fecha) : null;
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Justo ahora';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Hace ${diff.inHours} h';
    if (diff.inDays < 7) return 'Hace ${diff.inDays} d';
    return '${dt.day}/${dt.month}';
  }

  @override
  Widget build(BuildContext context) {
    final username = (usuario['username_usu'] as String?) ?? 'Gamer';
    final pais = usuario['pais_usu'] as String?;
    final tipo = usuario['tipo_publi_reciente'] as String?;
    final verificado = usuario['steam_vinculado'] == true;
    final enComun = usuario['juegos_en_comun'] as int? ?? 0;
    final rep = double.tryParse('${usuario['repu_usu']}');
    final bio = usuario['descrip_usu'] as String?;
    final comunes = ((usuario['juegos_comunes_muestra'] as List<dynamic>?) ?? [])
        .map((j) => Map<String, dynamic>.from(j as Map))
        .toList();
    final juegoReciente = usuario['juego_reciente'] as Map<String, dynamic>?;

    return Material(
      color: SteamColors.bgPanel,
      borderRadius: BorderRadius.circular(SteamRadii.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(SteamRadii.sm),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(SteamRadii.sm),
            border: Border.all(color: SteamColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [SteamColors.blue, SteamColors.teal],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      username.isNotEmpty ? username[0].toUpperCase() : '?',
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                username,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: SteamColors.light,
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (verificado) ...[
                              const SizedBox(width: 5),
                              const Icon(Icons.verified_rounded, size: 14, color: SteamColors.blue),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            if (pais != null && pais.isNotEmpty) ...[
                              Icon(Icons.public, size: 11, color: SteamColors.muted),
                              const SizedBox(width: 3),
                              Text(
                                PaisUtil.codigoANombre(pais),
                                style: const TextStyle(color: SteamColors.textSec, fontSize: 11.5),
                              ),
                              const SizedBox(width: 8),
                            ],
                            if (rep != null) ...[
                              const Icon(Icons.star_rounded, size: 12, color: SteamColors.yellow),
                              const SizedBox(width: 2),
                              Text(
                                rep.toStringAsFixed(1),
                                style: const TextStyle(color: SteamColors.textSec, fontSize: 11.5),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _hace(usuario['ultima_publicacion']),
                    style: const TextStyle(color: SteamColors.muted, fontSize: 11),
                  ),
                ],
              ),
              if (bio != null && bio.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  bio,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: SteamColors.textSec, fontSize: 12.5, height: 1.4),
                ),
              ],
              const SizedBox(height: 10),
              if (tipo != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: SteamColors.blue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    PublicacionConstants.etiquetaTipo(tipo),
                    style: const TextStyle(color: SteamColors.blue, fontSize: 10.5, fontWeight: FontWeight.w700),
                  ),
                ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        for (final j in comunes) ...[
                          _MiniCaratula(headerimg: j['headerimg_jg'] as String?),
                          const SizedBox(width: 4),
                        ],
                        if (comunes.isNotEmpty) const SizedBox(width: 4),
                        Text(
                          enComun > 0 ? '$enComun juego${enComun == 1 ? '' : 's'} en común' : 'Sin juegos en común',
                          style: TextStyle(
                            color: enComun > 0 ? SteamColors.teal : SteamColors.muted,
                            fontSize: 11.5,
                            fontWeight: enComun > 0 ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton(
                    onPressed: onTap,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: SteamColors.blue,
                      side: const BorderSide(color: SteamColors.blue),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    child: const Text('Ver perfil', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              if (juegoReciente != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: SteamColors.bgCard,
                    borderRadius: BorderRadius.circular(SteamRadii.sm),
                  ),
                  child: Row(
                    children: [
                      _MiniCaratula(headerimg: juegoReciente['headerimg_jg'] as String?),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          juegoReciente['nom_jg']?.toString() ?? 'Juego',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: SteamColors.light, fontSize: 12.5, fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (juegoReciente['horas'] != null)
                        Text(
                          '${juegoReciente['horas']} h jugadas',
                          style: const TextStyle(color: SteamColors.muted, fontSize: 11),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniCaratula extends StatelessWidget {
  final String? headerimg;

  const _MiniCaratula({required this.headerimg});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: SteamColors.bgInput,
        image: headerimg != null && headerimg!.isNotEmpty
            ? DecorationImage(image: NetworkImage(headerimg!), fit: BoxFit.cover)
            : null,
        border: Border.all(color: SteamColors.border),
      ),
      child: headerimg == null || headerimg!.isEmpty
          ? const Icon(Icons.videogame_asset_outlined, size: 13, color: SteamColors.muted)
          : null,
    );
  }
}

/// Panel derecho: filtros reales (juego/país/tipo de publicación/juegos en
/// común) + estadísticas reales derivadas de la lista ya cargada — nada de
/// "jugadores en línea" inventado (no hay tracking de presencia) ni
/// "idioma"/"tipo de juego" que no existen en el modelo de datos.
class _PanelLateral extends StatelessWidget {
  final TextEditingController busquedaCtrl;
  final ValueChanged<String> onBusqueda;
  final String? filtroJuegoNombre;
  final String? filtroPaisEtiqueta;
  final String? filtroTipoEtiqueta;
  final int minEnComun;
  final ValueChanged<int> onMinEnComun;
  final VoidCallback onAbrirFiltros;
  final VoidCallback onLimpiarFiltros;
  final List<Map<String, dynamic>> base;

  const _PanelLateral({
    required this.busquedaCtrl,
    required this.onBusqueda,
    required this.filtroJuegoNombre,
    required this.filtroPaisEtiqueta,
    required this.filtroTipoEtiqueta,
    required this.minEnComun,
    required this.onMinEnComun,
    required this.onAbrirFiltros,
    required this.onLimpiarFiltros,
    required this.base,
  });

  Map<String, int> _juegosPopulares() {
    final conteo = <String, int>{};
    for (final u in base) {
      final jr = u['juego_reciente'] as Map<String, dynamic>?;
      final nombre = jr?['nom_jg']?.toString();
      if (nombre != null && nombre.isNotEmpty) {
        conteo[nombre] = (conteo[nombre] ?? 0) + 1;
      }
    }
    final entradas = conteo.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Map.fromEntries(entradas.take(5));
  }

  @override
  Widget build(BuildContext context) {
    final tieneFiltros = filtroJuegoNombre != null ||
        filtroPaisEtiqueta != null ||
        filtroTipoEtiqueta != null ||
        minEnComun > 0;
    final populares = _juegosPopulares();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            onChanged: onBusqueda,
            controller: busquedaCtrl,
            style: const TextStyle(color: SteamColors.light, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Buscar por nombre…',
              hintStyle: const TextStyle(color: SteamColors.muted, fontSize: 13),
              prefixIcon: const Icon(Icons.search, color: SteamColors.muted, size: 18),
              filled: true,
              fillColor: SteamColors.bgInput,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(SteamRadii.sm),
                borderSide: const BorderSide(color: SteamColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(SteamRadii.sm),
                borderSide: const BorderSide(color: SteamColors.border),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'FILTROS',
                style: TextStyle(
                  color: SteamColors.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              if (tieneFiltros)
                TextButton(
                  onPressed: onLimpiarFiltros,
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 24)),
                  child: const Text('Limpiar', style: TextStyle(fontSize: 11.5)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          _BotonFiltro(
            label: filtroJuegoNombre ?? 'Todos los juegos',
            icon: Icons.videogame_asset_outlined,
            activo: filtroJuegoNombre != null,
            onTap: onAbrirFiltros,
          ),
          const SizedBox(height: 6),
          _BotonFiltro(
            label: filtroPaisEtiqueta ?? 'Todos los países',
            icon: Icons.public,
            activo: filtroPaisEtiqueta != null,
            onTap: onAbrirFiltros,
          ),
          const SizedBox(height: 6),
          _BotonFiltro(
            label: filtroTipoEtiqueta ?? 'Todos los tipos',
            icon: Icons.label_outline,
            activo: filtroTipoEtiqueta != null,
            onTap: onAbrirFiltros,
          ),
          const SizedBox(height: 14),
          const Text(
            'JUEGOS EN COMÚN',
            style: TextStyle(color: SteamColors.muted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _ChipUmbral(label: 'Cualquiera', activo: minEnComun == 0, onTap: () => onMinEnComun(0)),
              _ChipUmbral(label: '1+', activo: minEnComun == 1, onTap: () => onMinEnComun(1)),
              _ChipUmbral(label: '3+', activo: minEnComun == 3, onTap: () => onMinEnComun(3)),
              _ChipUmbral(label: '5+', activo: minEnComun == 5, onTap: () => onMinEnComun(5)),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'GAMERS ACTIVOS',
                style: TextStyle(color: SteamColors.muted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8),
              ),
              Text(
                '${base.length}',
                style: const TextStyle(color: SteamColors.light, fontSize: 13, fontWeight: FontWeight.w700, fontFamily: 'monospace'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Con publicaciones abiertas ahora.',
            style: TextStyle(color: SteamColors.muted, fontSize: 11),
          ),
          if (populares.isNotEmpty) ...[
            const SizedBox(height: 22),
            const Text(
              'JUEGOS POPULARES',
              style: TextStyle(color: SteamColors.muted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8),
            ),
            const SizedBox(height: 8),
            for (final entry in populares.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.key,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: SteamColors.textSec, fontSize: 12.5),
                      ),
                    ),
                    Text(
                      '${entry.value}',
                      style: const TextStyle(color: SteamColors.muted, fontSize: 12, fontFamily: 'monospace'),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _BotonFiltro extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool activo;
  final VoidCallback onTap;

  const _BotonFiltro({
    required this.label,
    required this.icon,
    required this.activo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SteamColors.bgInput,
      borderRadius: BorderRadius.circular(SteamRadii.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(SteamRadii.sm),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(SteamRadii.sm),
            border: Border.all(color: activo ? SteamColors.blue : SteamColors.border),
          ),
          child: Row(
            children: [
              Icon(icon, size: 15, color: activo ? SteamColors.blue : SteamColors.muted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: activo ? SteamColors.blue : SteamColors.textSec, fontSize: 12.5),
                ),
              ),
              Icon(Icons.chevron_right, size: 16, color: SteamColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChipUmbral extends StatelessWidget {
  final String label;
  final bool activo;
  final VoidCallback onTap;

  const _ChipUmbral({required this.label, required this.activo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: activo ? SteamColors.blue : SteamColors.bgInput,
      borderRadius: BorderRadius.circular(SteamRadii.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(SteamRadii.sm),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(SteamRadii.sm),
            border: Border.all(color: activo ? SteamColors.blue : SteamColors.border),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: activo ? Colors.white : SteamColors.textSec,
              fontSize: 12,
              fontWeight: activo ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}
