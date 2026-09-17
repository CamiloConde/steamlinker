import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/pais_util.dart';
import '../../../core/constants/publicacion_constants.dart';
import '../../../theme/colors.dart';
import '../../../theme/radii.dart';
import '../../../widgets/desktop_body_width.dart';
import '../../../widgets/drop_field.dart';
import '../../../widgets/steam_app_bar.dart';
import '../../../widgets/usuario_card.dart';
import '../../auth/providers/auth_provider.dart';
import '../../matches/screens/matches_screen.dart';
import '../../perfil/providers/perfil_provider.dart';
import '../../usuarios/screens/usuario_detalle_screen.dart';

/// Por debajo de este ancho se usa el feed móvil de tarjetas de siempre.
/// Igual al breakpoint de `ResponsiveShell`.
const _kEscritorio = 768.0;

class DescubrirGamersScreen extends StatefulWidget {
  const DescubrirGamersScreen({super.key});

  @override
  State<DescubrirGamersScreen> createState() => _DescubrirGamersScreenState();
}

class _DescubrirGamersScreenState extends State<DescubrirGamersScreen> {
  bool _inicializado = false;
  String? _filtroJuegoNombre;
  int? _filtroAppid;
  String? _filtroTipoEtiqueta;
  String? _filtroPaisEtiqueta;
  String _busqueda = '';

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

  List<Map<String, dynamic>> _listaFiltrada(PerfilProvider perfilProv, int? miId) {
    final q = _busqueda.trim().toLowerCase();
    return perfilProv.usuariosDescubrir
        .where((u) => miId == null || (u as Map)['id_usu'] != miId)
        .map((u) => Map<String, dynamic>.from(u as Map))
        .where((u) => q.isEmpty ||
            (u['username_usu']?.toString().toLowerCase() ?? '').contains(q))
        .toList();
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

    return Scaffold(
      backgroundColor: SteamColors.bgDeep,
      appBar: SteamAppBar(
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
      body: DesktopBodyWidth(
        maxWidth: esEscritorio ? 780 : 720,
        child: Column(
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
            if (esEscritorio)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: TextField(
                  onChanged: (v) => setState(() => _busqueda = v),
                  style: const TextStyle(color: SteamColors.light, fontSize: 13.5),
                  decoration: InputDecoration(
                    hintText: 'Buscar por nombre…',
                    hintStyle: const TextStyle(color: SteamColors.muted, fontSize: 13.5),
                    prefixIcon: const Icon(Icons.search, color: SteamColors.muted, size: 20),
                    filled: true,
                    fillColor: SteamColors.bgInput,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
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
                    : esEscritorio
                        ? _TablaGamers(
                            usuarios: _listaFiltrada(perfilProv, miId),
                            onTap: _abrirUsuario,
                          )
                        : _ListaGamers(
                            usuarios: _listaFiltrada(perfilProv, miId),
                            onTap: _abrirUsuario,
                          ),
              ),
            ),
          ],
        ),
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

  const _ListaGamers({required this.usuarios, required this.onTap});

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
      padding: const EdgeInsets.all(16),
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

/// Tabla de personas (wireframe turno 4, opción 4a): Descubrir lista
/// gente (biblioteca, reputación, en común) en vez de anuncios — la razón
/// de ser del producto es la columna EN COMÚN, calculada de la biblioteca
/// verificada, no de lo que el usuario diga tener.
class _TablaGamers extends StatelessWidget {
  final List<Map<String, dynamic>> usuarios;
  final ValueChanged<Map<String, dynamic>> onTap;

  const _TablaGamers({required this.usuarios, required this.onTap});

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

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            '${usuarios.length} gamer${usuarios.length == 1 ? '' : 's'} · ordenado por juegos en común',
            style: const TextStyle(
              color: SteamColors.muted,
              fontSize: 11.5,
              fontFamily: 'monospace',
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: SteamColors.bgCard,
            borderRadius: BorderRadius.circular(SteamRadii.sm),
            border: Border.all(color: SteamColors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _encabezado(),
              for (var i = 0; i < usuarios.length; i++)
                _FilaGamer(
                  usuario: usuarios[i],
                  ultima: i == usuarios.length - 1,
                  onTap: () => onTap(usuarios[i]),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _encabezado() {
    const estilo = TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.8,
      color: SteamColors.muted,
      fontFamily: 'monospace',
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: SteamColors.border)),
      ),
      child: const Row(
        children: [
          Expanded(child: Text('GAMER', style: estilo)),
          SizedBox(width: 74, child: Text('EN COMÚN', style: estilo, textAlign: TextAlign.right)),
          SizedBox(width: 56, child: Text('JUEGOS', style: estilo, textAlign: TextAlign.right)),
          SizedBox(width: 46, child: Text('REP', style: estilo, textAlign: TextAlign.right)),
          SizedBox(width: 64, child: Text('ACTIVO', style: estilo, textAlign: TextAlign.right)),
          SizedBox(width: 56),
        ],
      ),
    );
  }
}

class _FilaGamer extends StatelessWidget {
  final Map<String, dynamic> usuario;
  final bool ultima;
  final VoidCallback onTap;

  const _FilaGamer({required this.usuario, required this.ultima, required this.onTap});

  static String _hace(dynamic fecha) {
    if (fecha == null) return '—';
    final dt = fecha is String ? DateTime.tryParse(fecha) : null;
    if (dt == null) return '—';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'ahora';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min';
    if (diff.inHours < 24) return '${diff.inHours} h';
    if (diff.inDays < 7) return '${diff.inDays} d';
    return '${dt.day}/${dt.month}';
  }

  @override
  Widget build(BuildContext context) {
    const numero = TextStyle(fontFamily: 'monospace', fontSize: 12.5, color: SteamColors.light);
    final username = (usuario['username_usu'] as String?) ?? 'Gamer';
    final pais = usuario['pais_usu'] as String?;
    final tipo = usuario['tipo_publi_reciente'] as String?;
    final verificado = usuario['steam_vinculado'] == true;
    final enComun = usuario['juegos_en_comun'] as int? ?? 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
          decoration: BoxDecoration(
            border: ultima
                ? null
                : const Border(bottom: BorderSide(color: Color(0xFF1C2338))),
          ),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
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
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(width: 9),
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
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (verificado) ...[
                                const SizedBox(width: 4),
                                const Text('✓', style: TextStyle(color: SteamColors.blue, fontSize: 11)),
                              ],
                            ],
                          ),
                          Text(
                            [
                              if (pais != null && pais.isNotEmpty) PaisUtil.codigoANombre(pais).toUpperCase(),
                              if (tipo != null) PublicacionConstants.etiquetaTipo(tipo).toUpperCase(),
                            ].join(' · '),
                            style: const TextStyle(color: SteamColors.muted, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 74,
                child: Text(
                  '$enComun',
                  textAlign: TextAlign.right,
                  style: numero.copyWith(color: enComun > 0 ? SteamColors.teal : SteamColors.muted),
                ),
              ),
              SizedBox(
                width: 56,
                child: Text('${usuario['total_juegos'] ?? 0}', textAlign: TextAlign.right, style: numero),
              ),
              SizedBox(
                width: 46,
                child: Text(
                  double.tryParse('${usuario['repu_usu']}')?.toStringAsFixed(1) ?? '—',
                  textAlign: TextAlign.right,
                  style: numero,
                ),
              ),
              SizedBox(
                width: 64,
                child: Text(
                  _hace(usuario['ultima_publicacion']),
                  textAlign: TextAlign.right,
                  style: numero.copyWith(color: SteamColors.muted, fontSize: 11),
                ),
              ),
              SizedBox(
                width: 56,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton(
                    onPressed: onTap,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: SteamColors.textSec,
                      side: const BorderSide(color: SteamColors.border),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      minimumSize: Size.zero,
                    ),
                    child: const Text('Ver', style: TextStyle(fontSize: 11.5)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
