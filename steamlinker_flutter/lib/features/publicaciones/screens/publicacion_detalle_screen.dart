import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/pais_util.dart';
import '../../../core/constants/publicacion_constants.dart';
import '../../../core/utils/relacion_helper.dart';
import '../../../theme/colors.dart';
import '../../../theme/radii.dart';
import '../../../widgets/badge_origen_juego.dart';
import '../../../widgets/relacion_status_chip.dart'
    show RelacionStatusChip, RelacionStatusRow;
import '../../../widgets/steam_app_bar.dart';
import '../../../widgets/steam_buttons.dart';
import '../../../widgets/reportar_usuario_dialog.dart';
import '../../../widgets/steam_toast.dart';
import '../../auth/providers/auth_provider.dart';
import '../../chat/providers/chat_provider.dart';
import '../../chat/screens/chat_conversation_screen.dart';
import '../../matches/providers/matches_provider.dart';
import '../../notifications/providers/notificaciones_provider.dart';
import '../../perfil/providers/perfil_provider.dart';
import '../../usuarios/screens/usuario_detalle_screen.dart';
import '../providers/publicaciones_provider.dart';

class PublicacionDetalleScreen extends StatefulWidget {
  final int idPubli;

  const PublicacionDetalleScreen({super.key, required this.idPubli});

  @override
  State<PublicacionDetalleScreen> createState() =>
      _PublicacionDetalleScreenState();
}

class _PublicacionDetalleScreenState extends State<PublicacionDetalleScreen> {
  RelacionResumen? _relacion;
  bool _cargandoRelacion = false;
  bool _enviandoMatch = false;
  final _comentarioController = TextEditingController();
  int? _respondiendoAId;
  String? _respondiendoAUsuario;

  @override
  void dispose() {
    _comentarioController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargar());
  }

  Future<void> _cargar() async {
    final prov = context.read<PublicacionesProvider>();
    final perfilProv = context.read<PerfilProvider>();
    final miId = context.read<AuthProvider>().usuario?['id'] as int?;
    await prov.cargarPorId(widget.idPubli);
    if (!mounted) return;
    await Future.wait([
      _cargarRelacion(),
      prov.cargarComentarios(widget.idPubli),
      if (miId != null && perfilProv.juegos.isEmpty)
        perfilProv.cargarPerfil(miId),
    ]);
  }

  Future<void> _enviarComentario() async {
    final texto = _comentarioController.text.trim();
    if (texto.length < 2) {
      showSteamToast(context, 'Escribe un comentario', SteamColors.orange);
      return;
    }

    final prov = context.read<PublicacionesProvider>();
    final ok = await prov.enviarComentario(
      widget.idPubli,
      texto,
      idPadre: _respondiendoAId,
    );
    if (!mounted) return;

    if (ok) {
      _comentarioController.clear();
      setState(() {
        _respondiendoAId = null;
        _respondiendoAUsuario = null;
      });
      context.read<NotificacionesProvider>().cargarContador();
    } else {
      showSteamToast(context, prov.error ?? 'No se pudo comentar', Colors.red);
    }
  }

  Future<void> _cargarRelacion() async {
    final pub = context.read<PublicacionesProvider>().detalle;
    final autorId = pub?['id_usu'] as int?;
    final miId = context.read<AuthProvider>().usuario?['id'] as int?;
    if (autorId == null || miId == null || autorId == miId) return;

    setState(() => _cargandoRelacion = true);
    final data = await context.read<MatchesProvider>().consultarEstado(autorId);
    if (!mounted) return;
    setState(() {
      _cargandoRelacion = false;
      _relacion = data != null ? RelacionResumen.desdeApi(data) : null;
    });
  }

  Future<void> _enviarMatch() async {
    final pub = context.read<PublicacionesProvider>().detalle;
    final autorId = pub?['id_usu'] as int?;
    if (autorId == null) return;

    setState(() => _enviandoMatch = true);
    final exito = await context.read<MatchesProvider>().enviar(
      autorId,
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

  Future<void> _abrirChat(int autorId, String nombre) async {
    final chatProv = context.read<ChatProvider>();
    await chatProv.cargarConversaciones();

    int? chatId;
    for (final c in chatProv.conversaciones) {
      final chat = Map<String, dynamic>.from(c as Map);
      if (ChatProvider.otroUserId(chat) == autorId) {
        chatId = chat['id_chat'] as int?;
        break;
      }
    }

    chatId ??= await chatProv.iniciarChat(autorId);
    if (!mounted) return;
    if (chatId == null) {
      showSteamToast(
        context,
        chatProv.error ?? 'No se pudo abrir el chat',
        Colors.red,
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatConversationScreen(
          chatId: chatId!,
          otroNombre: nombre,
          otroUserId: autorId,
        ),
      ),
    );
    await _cargarRelacion();
  }

  void _irPerfil(Map<String, dynamic> pub) {
    final autorId = pub['id_usu'] as int?;
    if (autorId == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UsuarioDetalleScreen(
          userId: autorId,
          idPubli: widget.idPubli,
          tituloPublicacion: pub['titulo_publi'] as String?,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<PublicacionesProvider>();
    final auth = context.watch<AuthProvider>();
    final perfilProv = context.watch<PerfilProvider>();
    final pub = prov.detalle;
    final miId = auth.usuario?['id'];
    final esMia = pub != null && miId == pub['id_usu'];
    final autorId = pub?['id_usu'] as int?;

    final tieneJuego =
        pub != null &&
        !esMia &&
        (pub['juegos'] as List<dynamic>? ?? []).any((j) {
          final map = j as Map;
          // Solo cuenta juegos que el autor de verdad tiene -- uno que
          // solo está buscando (intencion_pjg == 'busco') no es un punto
          // en común real, sería engañoso decirle al usuario "tú también
          // tienes X" sobre un juego que el autor ni siquiera posee.
          if (map['intencion_pjg'] == 'busco') return false;
          final appid = map['appid'];
          // Solo cuenta si el juego viene de la biblioteca de Steam de
          // verdad -- uno agregado a mano no deberia mostrarse como
          // "verificado" (ver HANDOFF.md).
          return perfilProv.juegos.any(
            (mio) => mio['appid'] == appid && mio['origen'] == 'steam',
          );
        });

    return Scaffold(
      backgroundColor: SteamColors.bgDeep,
      appBar: SteamAppBar(
        title: 'PUBLICACIÓN',
        actions: esMia || autorId == null
            ? null
            : [
                IconButton(
                  icon: const Icon(
                    Icons.flag_outlined,
                    color: SteamColors.muted,
                  ),
                  tooltip: 'Reportar autor',
                  onPressed: () async {
                    final nombre =
                        pub?['username_usu']?.toString() ?? 'Usuario';
                    final ok = await mostrarReportarUsuarioDialog(
                      context,
                      nombreUsuario: nombre,
                      idReportado: autorId,
                    );
                    if (ok == true && context.mounted) {
                      showSteamToast(
                        context,
                        'Reporte enviado',
                        SteamColors.green,
                      );
                    }
                  },
                ),
              ],
      ),
      body: prov.cargandoDetalle
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(SteamColors.blue),
              ),
            )
          : prov.error != null && pub == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  prov.error!,
                  style: const TextStyle(color: SteamColors.light),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : pub == null
          ? const SizedBox.shrink()
          : RefreshIndicator(
              color: SteamColors.blue,
              backgroundColor: SteamColors.bgDeep,
              onRefresh: _cargar,
              child: ListView(
                padding: const EdgeInsets.all(16),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: SteamColors.blue.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(SteamRadii.sm),
                        ),
                        child: Text(
                          PublicacionConstants.etiquetaTipo(pub['tipo_publi']),
                          style: const TextStyle(
                            color: SteamColors.blue,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (_cargandoRelacion)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        RelacionStatusChip(relacion: _relacion),
                      const Spacer(),
                      if (pub['estado_publi'] == false) const _EstadoCerrada(),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    pub['titulo_publi'] ?? '',
                    style: const TextStyle(
                      color: SteamColors.light,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    pub['descrip_publi'] ?? 'Sin descripción',
                    style: const TextStyle(
                      color: SteamColors.textSec,
                      fontSize: 14,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _AutorSection(pub: pub, onTapPerfil: () => _irPerfil(pub)),
                  if (pub['cupos_totales'] != null) ...[
                    const SizedBox(height: 12),
                    _PanelCupos(pub: pub),
                  ],
                  if (tieneJuego) ...[
                    const SizedBox(height: 10),
                    const _TieneJuegoBox(),
                  ],
                  const SizedBox(height: 16),
                  if (!esMia && autorId != null) ...[
                    RelacionStatusRow(relacion: _relacion),
                    const SizedBox(height: 12),
                    if (_relacion?.matchAceptado == true ||
                        _relacion?.sonAmigos == true)
                      SteamButtonPrimary(
                        label: 'Abrir chat',
                        icon: Icons.chat_bubble_outline,
                        onTap: (_) => _abrirChat(
                          autorId,
                          pub['username_usu']?.toString() ?? 'Usuario',
                        ),
                      )
                    else if (_relacion?.puedeEnviarMatch == true)
                      SteamButtonPrimary(
                        label: _enviandoMatch ? 'Enviando...' : 'Enviar match',
                        icon: Icons.handshake_outlined,
                        onTap: _enviandoMatch ? null : (_) => _enviarMatch(),
                      )
                    else if (_relacion?.matchPendiente == true)
                      SteamButtonOutline(
                        label: _relacion!.matchSoySolicitante
                            ? 'Match pendiente'
                            : 'Ver solicitudes',
                        onTap: _relacion!.matchSoySolicitante
                            ? null
                            : () => Navigator.pop(context),
                      ),
                    const SizedBox(height: 10),
                    SteamButtonOutline(
                      label: 'Ver perfil completo',
                      onTap: () => _irPerfil(pub),
                    ),
                  ],
                  if (esMia) ...[
                    SteamButtonOutline(
                      label: 'Cerrar publicación',
                      onTap: () async {
                        final ok = await prov.cerrar(widget.idPubli);
                        if (!context.mounted) return;
                        if (ok) {
                          Navigator.pop(context, true);
                        } else if (prov.error != null) {
                          showSteamToast(context, prov.error!, Colors.red);
                        }
                      },
                    ),
                  ],
                  const SizedBox(height: 20),
                  const Text(
                    'Juegos de la publicación',
                    style: TextStyle(
                      color: SteamColors.light,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _JuegosLista(juegos: (pub['juegos'] as List<dynamic>?) ?? []),
                  const SizedBox(height: 24),
                  _ComentariosSection(
                    idPubli: widget.idPubli,
                    comentarioController: _comentarioController,
                    respondiendoAId: _respondiendoAId,
                    respondiendoAUsuario: _respondiendoAUsuario,
                    onCancelarRespuesta: () => setState(() {
                      _respondiendoAId = null;
                      _respondiendoAUsuario = null;
                    }),
                    onResponder: (id, usuario) => setState(() {
                      _respondiendoAId = id;
                      _respondiendoAUsuario = usuario;
                    }),
                    onEnviar: _enviarComentario,
                  ),
                ],
              ),
            ),
    );
  }
}

class _ComentariosSection extends StatelessWidget {
  final int idPubli;
  final TextEditingController comentarioController;
  final int? respondiendoAId;
  final String? respondiendoAUsuario;
  final VoidCallback onCancelarRespuesta;
  final void Function(int id, String usuario) onResponder;
  final VoidCallback onEnviar;

  const _ComentariosSection({
    required this.idPubli,
    required this.comentarioController,
    required this.respondiendoAId,
    required this.respondiendoAUsuario,
    required this.onCancelarRespuesta,
    required this.onResponder,
    required this.onEnviar,
  });

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<PublicacionesProvider>();
    final miId = context.watch<AuthProvider>().usuario?['id'];

    final raices = prov.comentarios.where((c) {
      final m = Map<String, dynamic>.from(c as Map);
      return m['id_padre'] == null;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Text(
              'Comentarios',
              style: TextStyle(
                color: SteamColors.light,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '(${prov.comentarios.length})',
              style: const TextStyle(color: SteamColors.muted, fontSize: 13),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (respondiendoAUsuario != null)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: SteamColors.bgCard,
              borderRadius: BorderRadius.circular(SteamRadii.sm),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Respondiendo a $respondiendoAUsuario',
                    style: const TextStyle(
                      color: SteamColors.blue,
                      fontSize: 12,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.close,
                    size: 18,
                    color: SteamColors.muted,
                  ),
                  tooltip: 'Cancelar respuesta',
                  onPressed: onCancelarRespuesta,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: comentarioController,
                maxLines: 3,
                minLines: 1,
                style: const TextStyle(color: SteamColors.light, fontSize: 13),
                decoration: const InputDecoration(
                  hintText: 'Escribe un comentario...',
                  hintStyle: TextStyle(color: SteamColors.muted),
                  filled: true,
                  fillColor: SteamColors.bgInput,
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SteamButtonPrimary(
              label: prov.enviandoComentario ? '...' : 'Enviar',
              icon: Icons.send_rounded,
              fullWidth: false,
              compact: true,
              onTap: prov.enviandoComentario ? null : (_) => onEnviar(),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (prov.cargandoComentarios)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else if (raices.isEmpty)
          const Text(
            'Sé el primero en comentar.',
            style: TextStyle(color: SteamColors.textSec, fontSize: 13),
          )
        else
          ...raices.map((c) {
            final coment = Map<String, dynamic>.from(c as Map);
            final respuestas = prov.comentarios.where((r) {
              final m = Map<String, dynamic>.from(r as Map);
              return m['id_padre'] == coment['id_coment'];
            }).toList();

            return _ComentarioTile(
              comentario: coment,
              respuestas: respuestas,
              miId: miId,
              onResponder: onResponder,
            );
          }),
      ],
    );
  }
}

class _ComentarioTile extends StatelessWidget {
  final Map<String, dynamic> comentario;
  final List<dynamic> respuestas;
  final int? miId;
  final void Function(int id, String usuario) onResponder;

  const _ComentarioTile({
    required this.comentario,
    required this.respuestas,
    required this.miId,
    required this.onResponder,
  });

  @override
  Widget build(BuildContext context) {
    final id = comentario['id_coment'] as int;
    final autor = comentario['username_usu']?.toString() ?? 'Usuario';
    final esMio = miId != null && comentario['id_usu'] == miId;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ComentarioBubble(
            autor: autor,
            texto: comentario['texto_coment']?.toString() ?? '',
            esMio: esMio,
            onResponder: () => onResponder(id, autor),
          ),
          ...respuestas.map((r) {
            final resp = Map<String, dynamic>.from(r as Map);
            final autorR = resp['username_usu']?.toString() ?? 'Usuario';
            final esMioR = miId != null && resp['id_usu'] == miId;
            return Padding(
              padding: const EdgeInsets.only(left: 20, top: 8),
              child: _ComentarioBubble(
                autor: autorR,
                texto: resp['texto_coment']?.toString() ?? '',
                esMio: esMioR,
                esRespuesta: true,
                onResponder: () =>
                    onResponder(resp['id_coment'] as int, autorR),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _ComentarioBubble extends StatelessWidget {
  final String autor;
  final String texto;
  final bool esMio;
  final bool esRespuesta;
  final VoidCallback onResponder;

  const _ComentarioBubble({
    required this.autor,
    required this.texto,
    required this.esMio,
    required this.onResponder,
    this.esRespuesta = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: esMio
            ? SteamColors.blue.withValues(alpha: 0.12)
            : SteamColors.bgPanel,
        borderRadius: BorderRadius.circular(SteamRadii.sm),
        border: Border.all(color: SteamColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                autor,
                style: TextStyle(
                  color: esMio ? SteamColors.blue : SteamColors.light,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (esRespuesta) ...[
                const SizedBox(width: 6),
                const Text(
                  '· respuesta',
                  style: TextStyle(color: SteamColors.muted, fontSize: 10),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            texto,
            style: const TextStyle(color: SteamColors.textSec, fontSize: 13),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onResponder,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Responder', style: TextStyle(fontSize: 11)),
            ),
          ),
        ],
      ),
    );
  }
}

class _EstadoCerrada extends StatelessWidget {
  const _EstadoCerrada();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: SteamColors.red.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(SteamRadii.sm),
      ),
      child: const Text(
        'Cerrada',
        style: TextStyle(
          color: SteamColors.red,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Panel de cupos (wireframe turno 4, opción 4c): hace visible lo que el
/// backend ya calcula (matches aceptados / cupos_totales) con el roster
/// real de quién confirmó, en vez de solo un número suelto.
class _PanelCupos extends StatelessWidget {
  final Map<String, dynamic> pub;

  const _PanelCupos({required this.pub});

  static const _tiposFamilia = ['busco_familia', 'busco_miembros'];

  @override
  Widget build(BuildContext context) {
    final total = pub['cupos_totales'] as int;
    final confirmados = ((pub['confirmados'] as List<dynamic>?) ?? [])
        .map((c) => Map<String, dynamic>.from(c as Map))
        .toList();
    final ocupados = confirmados.length;
    final libres = (total - ocupados).clamp(0, total);
    const maxFilas = 8;
    final esFamilia = _tiposFamilia.contains(pub['tipo_publi']);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SteamColors.bgPanel,
        borderRadius: BorderRadius.circular(SteamRadii.sm),
        border: Border.all(color: SteamColors.blue),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'CONFIRMADOS',
                style: TextStyle(
                  color: SteamColors.muted,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  fontFamily: 'monospace',
                ),
              ),
              if (esFamilia) ...[
                const Spacer(),
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => _mostrarFaqRegion(context),
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(
                      Icons.help_outline,
                      size: 15,
                      color: SteamColors.muted,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 2),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$ocupados',
                  style: const TextStyle(
                    color: SteamColors.teal,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
                  ),
                ),
                TextSpan(
                  text: '/$total',
                  style: const TextStyle(
                    color: SteamColors.muted,
                    fontSize: 15,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: total > 0 ? (ocupados / total).clamp(0, 1) : 0,
              minHeight: 5,
              backgroundColor: SteamColors.bgInput,
              valueColor: const AlwaysStoppedAnimation(SteamColors.teal),
            ),
          ),
          const SizedBox(height: 10),
          for (final c in confirmados.take(maxFilas))
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: _FilaCupo(
                texto: c['username_usu']?.toString() ?? 'Usuario',
              ),
            ),
          for (var i = 0; i < libres && confirmados.length + i < maxFilas; i++)
            const Padding(
              padding: EdgeInsets.only(bottom: 7),
              child: _FilaCupo(texto: 'Libre', libre: true),
            ),
          if (confirmados.length + libres > maxFilas)
            Text(
              '+${confirmados.length + libres - maxFilas} más',
              style: const TextStyle(color: SteamColors.muted, fontSize: 11),
            ),
        ],
      ),
    );
  }

  void _mostrarFaqRegion(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: SteamColors.bgPanel,
        title: const Text(
          '¿Steam dice que no puedes unirte por región?',
          style: TextStyle(color: SteamColors.light, fontSize: 15),
        ),
        content: const Text(
          'Steam a veces bloquea unirse a una Familia si detecta que el país '
          'de tu cuenta no coincide con el del resto de la familia. No es '
          'algo que SteamMatch controle — es una regla de Steam. Dos formas '
          'con las que otros usuarios han resuelto esto:\n\n'
          '• Que una persona inicie sesión en Steam desde el computador de '
          'la otra (o viceversa) al momento de unirse.\n\n'
          '• Usar una VPN con un servidor en el país de la familia mientras '
          'se hace la unión.\n\n'
          'Ninguna de las dos garantiza que funcione siempre, y quedan '
          'sujetas a las políticas de Steam.',
          style: TextStyle(
            color: SteamColors.textSec,
            fontSize: 13,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }
}

class _FilaCupo extends StatelessWidget {
  final String texto;
  final bool libre;

  const _FilaCupo({required this.texto, this.libre = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (libre)
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: SteamColors.border,
                style: BorderStyle.solid,
              ),
            ),
          )
        else
          Container(
            width: 22,
            height: 22,
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
              texto.isNotEmpty ? texto[0].toUpperCase() : '?',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        const SizedBox(width: 9),
        Text(
          texto,
          style: TextStyle(
            color: libre ? SteamColors.muted : SteamColors.light,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

class _TieneJuegoBox extends StatelessWidget {
  const _TieneJuegoBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: SteamColors.bgPanel,
        borderRadius: BorderRadius.circular(SteamRadii.sm),
        border: Border.all(color: SteamColors.border),
      ),
      child: const Row(
        children: [
          Icon(Icons.check_circle, size: 16, color: SteamColors.teal),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Tienes este juego verificado en tu biblioteca',
              style: TextStyle(
                color: SteamColors.teal,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AutorSection extends StatelessWidget {
  final Map<String, dynamic> pub;
  final VoidCallback onTapPerfil;

  const _AutorSection({required this.pub, required this.onTapPerfil});

  @override
  Widget build(BuildContext context) {
    final repu = pub['repu_usu'];
    return InkWell(
      onTap: onTapPerfil,
      borderRadius: BorderRadius.circular(SteamRadii.sm),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: SteamColors.bgPanel,
          borderRadius: BorderRadius.circular(SteamRadii.sm),
          border: Border.all(color: SteamColors.border),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: SteamColors.blue.withValues(alpha: 0.2),
              child: Text(
                (pub['username_usu']?.toString() ?? 'U')[0].toUpperCase(),
                style: const TextStyle(
                  color: SteamColors.blue,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pub['username_usu'] ?? 'Autor',
                    style: const TextStyle(
                      color: SteamColors.light,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        PaisUtil.codigoANombre(pub['pais_usu']?.toString()),
                        style: const TextStyle(
                          color: SteamColors.textSec,
                          fontSize: 12,
                        ),
                      ),
                      if (repu != null) ...[
                        const SizedBox(width: 12),
                        Text(
                          '★ ${double.tryParse(repu.toString())?.toStringAsFixed(1) ?? repu}',
                          style: const TextStyle(
                            color: SteamColors.green,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: SteamColors.muted),
          ],
        ),
      ),
    );
  }
}

class _JuegosLista extends StatelessWidget {
  final List<dynamic> juegos;

  const _JuegosLista({required this.juegos});

  @override
  Widget build(BuildContext context) {
    if (juegos.isEmpty) {
      return const Text(
        'Sin juegos asociados.',
        style: TextStyle(color: SteamColors.textSec, fontSize: 13),
      );
    }

    final mapas = juegos
        .map((j) => Map<String, dynamic>.from(j as Map))
        .toList();
    final tiene = mapas.where((j) => j['intencion_pjg'] != 'busco').toList();
    final busca = mapas.where((j) => j['intencion_pjg'] == 'busco').toList();

    // Antes esta pantalla mostraba "lo que tengo" y "lo que busco" mezclados
    // en una sola lista sin distinción -- el usuario reportó que un juego
    // que pedía (ej. Spider-Man 2, marcado como preferido, no algo suyo)
    // aparecía igual que los que sí tiene, dando a entender que era parte
    // de su biblioteca. Ahora se separan en dos grupos; si solo hay uno de
    // los dos, se omite el subtítulo redundante (caso más común: solo
    // ofrece juegos, no pide ninguno en particular).
    final mostrarSubtitulos = tiene.isNotEmpty && busca.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (tiene.isNotEmpty) ...[
          if (mostrarSubtitulos) _SubtituloJuegos(texto: 'Tiene'),
          ..._filas(tiene, esBusca: false),
        ],
        if (busca.isNotEmpty) ...[
          if (mostrarSubtitulos)
            Padding(
              padding: EdgeInsets.only(top: tiene.isNotEmpty ? 8 : 0),
              child: _SubtituloJuegos(texto: 'Busca'),
            ),
          ..._filas(busca, esBusca: true),
        ],
      ],
    );
  }

  List<Widget> _filas(
    List<Map<String, dynamic>> lista, {
    required bool esBusca,
  }) {
    return lista.map((map) {
      final header = map['headerimg_jg']?.toString();
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: SteamColors.bgPanel,
            borderRadius: BorderRadius.circular(SteamRadii.sm),
            border: Border.all(color: SteamColors.border),
          ),
          child: Row(
            children: [
              Semantics(
                image: true,
                label: 'Carátula de ${map['nom_jg'] ?? 'juego'}',
                child: Container(
                  width: 56,
                  height: 32,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(SteamRadii.sm),
                    color: SteamColors.bgCard,
                    image: header != null && header.isNotEmpty
                        ? DecorationImage(
                            image: NetworkImage(header),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: header == null || header.isEmpty
                      ? const Icon(
                          Icons.videogame_asset,
                          color: SteamColors.muted,
                          size: 18,
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  map['nom_jg'] ?? 'Juego',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: SteamColors.light,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // "Busca" no tiene insignia STEAM/MANUAL -- no aplica, el
              // usuario no lo tiene. Ícono de preferencia en su lugar.
              if (esBusca)
                const Icon(
                  Icons.star_outline,
                  color: SteamColors.muted,
                  size: 16,
                )
              else
                BadgeOrigenJuego(esSteam: map['origen_pjg'] == 'steam'),
            ],
          ),
        ),
      );
    }).toList();
  }
}

class _SubtituloJuegos extends StatelessWidget {
  final String texto;

  const _SubtituloJuegos({required this.texto});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        texto,
        style: const TextStyle(
          color: SteamColors.textSec,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
        ),
      ),
    );
  }
}
