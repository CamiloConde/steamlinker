import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/pais_util.dart';
import '../../../core/constants/publicacion_constants.dart';
import '../../../theme/colors.dart';
import '../../../widgets/desktop_body_width.dart';
import '../../../widgets/drop_field.dart';
import '../../../widgets/steam_app_bar.dart';
import '../../../widgets/usuario_card.dart';
import '../../auth/providers/auth_provider.dart';
import '../../matches/screens/matches_screen.dart';
import '../../perfil/providers/perfil_provider.dart';
import '../../usuarios/screens/usuario_detalle_screen.dart';

class DescubrirGamersScreen extends StatefulWidget {
  final bool embebida;

  const DescubrirGamersScreen({super.key, this.embebida = false});

  @override
  State<DescubrirGamersScreen> createState() => _DescubrirGamersScreenState();
}

class _DescubrirGamersScreenState extends State<DescubrirGamersScreen> {
  bool _inicializado = false;
  String? _filtroJuegoNombre;
  int? _filtroAppid;
  String? _filtroTipoEtiqueta;
  String? _filtroPaisEtiqueta;

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
    await perfil.descubrirUsuarios();
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

    final juegosFiltro = [
      'Todos los juegos',
      ...perfil.juegos.map((j) => j['nombre']?.toString() ?? 'Juego'),
    ];

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
                  DropField(
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
                    style: ElevatedButton.styleFrom(backgroundColor: SteamColors.blue),
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

  @override
  Widget build(BuildContext context) {
    final perfilProv = context.watch<PerfilProvider>();
    final auth = context.watch<AuthProvider>();
    final miId = auth.usuario?['id'];

    final acciones = [
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
        icon: const Icon(Icons.tune_rounded, color: SteamColors.muted),
        tooltip: 'Filtros',
        onPressed: _abrirFiltros,
      ),
      IconButton(
        icon: const Icon(Icons.refresh, color: SteamColors.blue),
        tooltip: 'Actualizar',
        onPressed: _recargar,
      ),
    ];

    final cuerpo = DesktopBodyWidth(child: Column(
      children: [
        if (widget.embebida)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: acciones),
          ),
        if (_filtroTipoEtiqueta != null ||
              _filtroPaisEtiqueta != null ||
              _filtroJuegoNombre != null)
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
            : perfilProv.usuariosDescubrir.isEmpty
                ? ListView(
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
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: perfilProv.usuariosDescubrir
                        .where((u) => miId == null || (u as Map)['id_usu'] != miId)
                        .length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final lista = perfilProv.usuariosDescubrir
                          .where((u) => miId == null || (u as Map)['id_usu'] != miId)
                          .toList();
                      final u = Map<String, dynamic>.from(lista[index] as Map);
                      final total = u['total_publicaciones'] ?? 0;
                      return UsuarioCard(
                        usuario: u,
                        subtitulo: u['descrip_usu']?.toString().isNotEmpty == true
                            ? u['descrip_usu']
                            : '$total publicación${total == 1 ? '' : 'es'} activa${total == 1 ? '' : 's'}',
                        onTap: () => _abrirUsuario(u),
                      );
                    },
                  ),
            ),
          ),
      ],
    ));

    if (widget.embebida) return cuerpo;

    return Scaffold(
      backgroundColor: SteamColors.bgDeep,
      appBar: SteamAppBar(title: 'DESCUBRIR', actions: acciones),
      body: cuerpo,
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
