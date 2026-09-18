import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/pais_util.dart';
import '../../../core/utils/relacion_helper.dart';
import '../../../theme/colors.dart';
import '../../../theme/radii.dart';
import '../../../widgets/relacion_status_chip.dart';
import '../../../widgets/calificar_dialog.dart';
import '../../../widgets/reportar_usuario_dialog.dart';
import '../../../widgets/steam_app_bar.dart';
import '../../calificaciones/screens/resenas_usuario_screen.dart';
import '../../../widgets/steam_buttons.dart';
import '../../../widgets/steam_card.dart';
import '../../../widgets/steam_toast.dart';
import '../../amistad/providers/amistad_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../calificaciones/providers/calificaciones_provider.dart';
import '../../chat/providers/chat_provider.dart';
import '../../chat/screens/chat_conversation_screen.dart';
import '../../matches/providers/matches_provider.dart';
import '../../notifications/providers/notificaciones_provider.dart';
import '../../perfil/providers/perfil_provider.dart';
import 'comparar_biblioteca_screen.dart';

class UsuarioDetalleScreen extends StatefulWidget {
  final int userId;
  final int? idPubli;
  final String? tituloPublicacion;

  const UsuarioDetalleScreen({
    super.key,
    required this.userId,
    this.idPubli,
    this.tituloPublicacion,
  });

  @override
  State<UsuarioDetalleScreen> createState() => _UsuarioDetalleScreenState();
}

class _UsuarioDetalleScreenState extends State<UsuarioDetalleScreen> {
  bool _cargando = true;
  String? _error;
  Map<String, dynamic>? _perfil;
  List<dynamic> _juegos = [];
  bool _bibliotecaOculta = false;
  bool _otroSteamVinculado = false;
  bool _yoSteamVinculado = false;
  bool _enviandoMatch = false;
  bool _enviandoAmistad = false;
  bool _comparando = false;
  RelacionResumen? _relacion;
  bool _cargandoRelacion = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MatchesProvider>().cargarTodo();
      context.read<AmistadProvider>().cargarTodo();
      _cargarRelacion();
    });
    _cargar();
  }

  Future<void> _cargarRelacion() async {
    final miId = context.read<AuthProvider>().usuario?['id'];
    if (miId == null || miId == widget.userId) return;

    setState(() => _cargandoRelacion = true);
    final data = await context.read<MatchesProvider>().consultarEstado(widget.userId);
    if (!mounted) return;
    setState(() {
      _cargandoRelacion = false;
      _relacion = data != null ? RelacionResumen.desdeApi(data) : null;
    });
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    final perfilProv = context.read<PerfilProvider>();
    final auth = context.read<AuthProvider>();
    final data = await perfilProv.cargarPerfilAjeno(widget.userId);
    if (!mounted) return;
    if (data == null) {
      setState(() {
        _cargando = false;
        _error = perfilProv.error ?? 'No se pudo cargar';
      });
      return;
    }

    var yoSteam = false;
    final miId = auth.usuario?['id'];
    if (miId != null) {
      if (perfilProv.perfil == null) {
        await perfilProv.cargarPerfil(miId);
      }
      yoSteam = perfilProv.perfil?['steam'] != null;
    }

    if (!mounted) return;
    setState(() {
      _perfil = data['perfil'] as Map<String, dynamic>;
      _juegos = data['juegos'] as List<dynamic>;
      _bibliotecaOculta = data['biblioteca_oculta'] == true;
      _otroSteamVinculado = data['steam_vinculado'] == true;
      _yoSteamVinculado = yoSteam;
      _cargando = false;
    });
  }

  bool get _puedeComparar =>
      !_bibliotecaOculta || (_yoSteamVinculado && _otroSteamVinculado);

  Future<void> _reportarUsuario() async {
    final nombre = _perfil?['username']?.toString() ?? 'Usuario';
    final enviado = await mostrarReportarUsuarioDialog(
      context,
      nombreUsuario: nombre,
      idReportado: widget.userId,
    );
    if (enviado == true && mounted) {
      showSteamToast(context, 'Reporte enviado', SteamColors.green);
    }
  }

  void _verResenas() {
    final nombre = _perfil?['username']?.toString() ?? 'Usuario';
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ResenasUsuarioScreen(
          userId: widget.userId,
          username: nombre,
        ),
      ),
    );
  }

  Future<void> _enviarMatch() async {
    setState(() => _enviandoMatch = true);
    final exito = await context.read<MatchesProvider>().enviar(
      widget.userId,
      idPubli: widget.idPubli,
    );
    if (!mounted) return;
    setState(() => _enviandoMatch = false);
    if (exito) {
      showSteamToast(context, 'Solicitud de match enviada', SteamColors.green);
      context.read<NotificacionesProvider>().cargarContador();
      await _cargarRelacion();
    } else {
      showSteamToast(
        context,
        context.read<MatchesProvider>().error ?? 'No se pudo enviar',
        Colors.red,
      );
    }
  }

  Future<void> _enviarAmistad() async {
    setState(() => _enviandoAmistad = true);
    final exito = await context.read<AmistadProvider>().enviar(widget.userId);
    if (!mounted) return;
    setState(() => _enviandoAmistad = false);
    if (exito) {
      showSteamToast(context, 'Solicitud de amistad enviada', SteamColors.green);
      context.read<NotificacionesProvider>().cargarContador();
      await _cargarRelacion();
    } else {
      showSteamToast(
        context,
        context.read<AmistadProvider>().error ?? 'No se pudo enviar',
        Colors.red,
      );
    }
  }

  Future<void> _compararBiblioteca() async {
    setState(() => _comparando = true);
    final resultado =
        await context.read<PerfilProvider>().compararBiblioteca(widget.userId);
    if (!mounted) return;
    setState(() => _comparando = false);

    if (resultado != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CompararBibliotecaScreen(resultado: resultado),
        ),
      );
    } else {
      showSteamToast(
        context,
        context.read<PerfilProvider>().error ?? 'No se pudo comparar',
        Colors.red,
      );
    }
  }

  Future<void> _abrirChat() async {
    final chatProv = context.read<ChatProvider>();
    await chatProv.cargarConversaciones();

    int? chatId;
    for (final c in chatProv.conversaciones) {
      final chat = Map<String, dynamic>.from(c as Map);
      if (ChatProvider.otroUserId(chat) == widget.userId) {
        chatId = chat['id_chat'] as int?;
        break;
      }
    }

    chatId ??= await chatProv.iniciarChat(widget.userId);

    if (!mounted) return;
    if (chatId == null) {
      showSteamToast(
        context,
        chatProv.error ?? 'No se pudo abrir el chat',
        Colors.red,
      );
      return;
    }

    final nombre = _perfil?['username']?.toString() ?? 'Usuario';
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatConversationScreen(
          chatId: chatId!,
          otroNombre: nombre,
          otroUserId: widget.userId,
        ),
      ),
    );
  }

  Future<void> _calificarMatch(Map<String, dynamic> match) async {
    final miId = context.read<AuthProvider>().usuario?['id'];
    final solicitante = match['id_solicitante'];
    final receptor = match['id_receptor'];
    final idCalificado = miId == solicitante ? receptor : solicitante;
    final nombre = _perfil?['username'] ?? 'usuario';

    final resultado = await mostrarCalificarDialog(context, nombreUsuario: nombre);
    if (resultado == null || !mounted) return;

    final exito = await context.read<CalificacionesProvider>().crear(
      idMatch: match['id_match'] as int,
      idCalificado: idCalificado as int,
      estrellas: resultado.estrellas,
      confiable: resultado.confiable,
      comentario: resultado.comentario,
    );

    if (!mounted) return;
    if (exito) {
      showSteamToast(context, 'Calificación enviada', SteamColors.green);
      await _cargar();
    } else {
      showSteamToast(
        context,
        context.read<CalificacionesProvider>().error ?? 'Error al calificar',
        Colors.red,
      );
    }
  }

  Map<String, dynamic>? _matchAceptadoConUsuario(MatchesProvider matches, int? miId) {
    if (miId == null || _relacion?.matchAceptado != true) return null;
    final idMatch = _relacion?.idMatch;
    for (final m in [...matches.recibidos, ...matches.enviados]) {
      final map = Map<String, dynamic>.from(m as Map);
      if (map['estado_match'] != 'Aceptada') continue;
      if (idMatch != null && map['id_match'] == idMatch) return map;
      final otro = map['id_solicitante'] == miId ? map['id_receptor'] : map['id_solicitante'];
      if (otro == widget.userId) return map;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final matchesProv = context.watch<MatchesProvider>();
    final miId = auth.usuario?['id'];
    final esYo = miId == widget.userId;
    final matchAceptado = _matchAceptadoConUsuario(matchesProv, miId);
    final puedeMatch = _relacion?.puedeEnviarMatch ?? true;
    final puedeAmistad = _relacion?.puedeEnviarAmistad ?? true;

    return Scaffold(
      backgroundColor: SteamColors.bgDeep,
      appBar: SteamAppBar(
        title: 'PERFIL',
        actions: esYo
            ? null
            : [
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: SteamColors.muted),
                  color: SteamColors.bgPanel,
                  onSelected: (v) {
                    if (v == 'reportar') _reportarUsuario();
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'reportar', child: Text('Reportar usuario')),
                  ],
                ),
              ],
      ),
      body: _cargando
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(SteamColors.blue),
              ),
            )
          : _error != null
              ? Center(
                  child: Text(_error!, style: const TextStyle(color: SteamColors.light)),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (widget.tituloPublicacion != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: SteamColors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(SteamRadii.sm),
                          border: Border.all(color: SteamColors.orange.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.campaign_outlined, color: SteamColors.orange, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                widget.tituloPublicacion!,
                                style: const TextStyle(color: SteamColors.light, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    SteamCard(
                      icon: Icons.person,
                      title: _perfil!['username'] ?? 'Usuario',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            _perfil!['descrip']?.toString().isNotEmpty == true
                                ? _perfil!['descrip']
                                : 'Sin descripción',
                            style: const TextStyle(color: SteamColors.textSec, fontSize: 13),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _ChipInfo(
                                label: PaisUtil.codigoANombre(_perfil!['pais']?.toString()),
                              ),
                              const SizedBox(width: 8),
                              _ChipInfo(
                                label: '★ ${(_perfil!['repu'] ?? 0).toString()}',
                                color: SteamColors.green,
                              ),
                            ],
                          ),
                          if (!esYo) ...[
                            const SizedBox(height: 12),
                            if (_cargandoRelacion)
                              const Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                            else ...[
                              RelacionStatusRow(relacion: _relacion),
                              const SizedBox(height: 12),
                            ],
                            if (puedeMatch) ...[
                              SteamButtonPrimary(
                                label: _enviandoMatch ? 'Enviando...' : 'Enviar match',
                                icon: Icons.handshake_outlined,
                                onTap: _enviandoMatch ? null : (_) => _enviarMatch(),
                              ),
                              const SizedBox(height: 10),
                            ],
                            if (puedeAmistad)
                              SteamButtonOutline(
                                label: _enviandoAmistad ? 'Enviando...' : 'Agregar amigo',
                                onTap: _enviandoAmistad ? null : _enviarAmistad,
                              )
                            else if (_relacion?.amistadPendiente == true)
                              SteamButtonOutline(
                                label: _relacion!.amistadSoySolicitante
                                    ? 'Amistad pendiente'
                                    : 'Solicitud de amistad recibida',
                                onTap: null,
                              )
                            else if (_relacion?.sonAmigos == true)
                              const Padding(
                                padding: EdgeInsets.only(bottom: 10),
                                child: RelacionStatusChip(
                                  relacion: RelacionResumen(amistadEstado: 'Aceptada'),
                                ),
                              ),
                            const SizedBox(height: 10),
                            if (_puedeComparar)
                              SteamButtonOutline(
                                label: _comparando
                                    ? 'Comparando...'
                                    : 'Comparar bibliotecas',
                                onTap: _comparando ? null : _compararBiblioteca,
                              )
                            else
                              const Text(
                                'Comparación no disponible: este usuario ocultó su biblioteca. '
                                'Ambos deben tener Steam vinculado para comparar en vivo.',
                                style: TextStyle(color: SteamColors.textSec, fontSize: 11),
                              ),
                            const SizedBox(height: 10),
                            SteamButtonOutline(
                              label: 'Ver reseñas',
                              onTap: _verResenas,
                            ),
                            if (_relacion?.matchAceptado == true ||
                                _relacion?.sonAmigos == true) ...[
                              const SizedBox(height: 10),
                              SteamButtonPrimary(
                                label: 'Abrir chat',
                                icon: Icons.chat_bubble_outline,
                                onTap: (_) => _abrirChat(),
                              ),
                            ],
                            if (matchAceptado != null) ...[
                              const SizedBox(height: 10),
                              SteamButtonOutline(
                                label: 'Calificar usuario',
                                onTap: () => _calificarMatch(matchAceptado),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SteamCard(
                      icon: Icons.videogame_asset_outlined,
                      title: _bibliotecaOculta
                          ? 'Biblioteca oculta'
                          : 'Biblioteca (${_juegos.length})',
                      child: _bibliotecaOculta
                          ? const Text(
                              'Este usuario ocultó su biblioteca en la configuración de privacidad.',
                              style: TextStyle(color: SteamColors.textSec, fontSize: 12),
                            )
                          : _juegos.isEmpty
                          ? const Text(
                              'Sin juegos visibles en el perfil.',
                              style: TextStyle(color: SteamColors.textSec, fontSize: 12),
                            )
                          : Column(
                              children: _juegos.take(8).map((j) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(SteamRadii.sm),
                                          color: SteamColors.bgPanel,
                                          image: (j['headerimg']?.toString().isNotEmpty == true)
                                              ? DecorationImage(
                                                  image: NetworkImage(j['headerimg']),
                                                  fit: BoxFit.cover,
                                                )
                                              : null,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          j['nombre'] ?? 'Juego',
                                          style: const TextStyle(
                                            color: SteamColors.light,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        '${j['horas'] ?? 0}h',
                                        style: const TextStyle(
                                          color: SteamColors.textSec,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                    ),
                  ],
                ),
    );
  }
}

class _ChipInfo extends StatelessWidget {
  final String label;
  final Color color;

  const _ChipInfo({required this.label, this.color = SteamColors.blue});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(SteamRadii.sm),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}
