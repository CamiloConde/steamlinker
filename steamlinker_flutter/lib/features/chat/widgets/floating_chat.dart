// Panel de chat flotante (lenguaje visual del wireframe: burbuja + ventana
// anclada abajo a la derecha, en vez de una pantalla completa de mensajes).
// Vive sobre el contenido en ResponsiveShell (solo escritorio).

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../theme/colors.dart';
import '../../../theme/radii.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/chat_provider.dart';

class FloatingChat extends StatefulWidget {
  const FloatingChat({super.key});

  @override
  State<FloatingChat> createState() => _FloatingChatState();
}

class _FloatingChatState extends State<FloatingChat> {
  bool _abierto = false;
  int? _chatId;
  String? _chatNombre;
  bool _inicializado = false;

  void _abrir() {
    setState(() => _abierto = true);
    if (!_inicializado) {
      _inicializado = true;
      context.read<ChatProvider>().cargarConversaciones();
    }
  }

  void _abrirConversacion(int id, String nombre) {
    setState(() {
      _chatId = id;
      _chatNombre = nombre;
    });
    context.read<ChatProvider>().cargarMensajes(id);
  }

  void _volverALista() {
    context.read<ChatProvider>().salirConversacion();
    context.read<ChatProvider>().cargarConversaciones();
    setState(() => _chatId = null);
  }

  void _cerrar() {
    setState(() {
      _abierto = false;
      _chatId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_abierto) {
      return _LauncherBubble(onTap: _abrir);
    }

    return _ChatPanel(
      chatId: _chatId,
      chatNombre: _chatNombre,
      onAbrirConversacion: _abrirConversacion,
      onVolver: _volverALista,
      onMinimizar: () => setState(() => _abierto = false),
      onCerrar: _cerrar,
    );
  }
}

class _LauncherBubble extends StatelessWidget {
  final VoidCallback onTap;

  const _LauncherBubble({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SteamColors.blue,
      shape: const CircleBorder(),
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 24),
        ),
      ),
    );
  }
}

class _ChatPanel extends StatelessWidget {
  final int? chatId;
  final String? chatNombre;
  final void Function(int id, String nombre) onAbrirConversacion;
  final VoidCallback onVolver;
  final VoidCallback onMinimizar;
  final VoidCallback onCerrar;

  const _ChatPanel({
    required this.chatId,
    required this.chatNombre,
    required this.onAbrirConversacion,
    required this.onVolver,
    required this.onMinimizar,
    required this.onCerrar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      height: 440,
      decoration: BoxDecoration(
        color: SteamColors.bgCard,
        borderRadius: BorderRadius.circular(SteamRadii.sm),
        border: Border.all(color: SteamColors.border),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 16, offset: Offset(0, 6)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _PanelHeader(
            titulo: chatId != null ? (chatNombre ?? 'Chat') : 'Mensajes',
            mostrarVolver: chatId != null,
            onVolver: onVolver,
            onMinimizar: onMinimizar,
            onCerrar: onCerrar,
          ),
          Expanded(
            child: chatId != null
                ? _ConversacionEmbebida(chatId: chatId!, otroNombre: chatNombre ?? 'Chat')
                : _ListaConversaciones(onAbrirConversacion: onAbrirConversacion),
          ),
        ],
      ),
    );
  }
}

class _PanelHeader extends StatelessWidget {
  final String titulo;
  final bool mostrarVolver;
  final VoidCallback onVolver;
  final VoidCallback onMinimizar;
  final VoidCallback onCerrar;

  const _PanelHeader({
    required this.titulo,
    required this.mostrarVolver,
    required this.onVolver,
    required this.onMinimizar,
    required this.onCerrar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: SteamColors.bgPanel,
      padding: const EdgeInsets.only(left: 4, right: 4),
      child: Row(
        children: [
          if (mostrarVolver)
            IconButton(
              icon: const Icon(Icons.arrow_back, size: 18, color: SteamColors.muted),
              tooltip: 'Volver a mensajes',
              onPressed: onVolver,
            )
          else
            const SizedBox(width: 12),
          Expanded(
            child: Text(
              titulo,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: SteamColors.light,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove, size: 18, color: SteamColors.muted),
            tooltip: 'Minimizar',
            onPressed: onMinimizar,
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: SteamColors.muted),
            tooltip: 'Cerrar',
            onPressed: onCerrar,
          ),
        ],
      ),
    );
  }
}

class _ListaConversaciones extends StatelessWidget {
  final void Function(int id, String nombre) onAbrirConversacion;

  const _ListaConversaciones({required this.onAbrirConversacion});

  @override
  Widget build(BuildContext context) {
    final chatProv = context.watch<ChatProvider>();

    if (chatProv.cargandoLista && chatProv.conversaciones.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation(SteamColors.blue),
        ),
      );
    }

    if (chatProv.conversaciones.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'No tienes conversaciones aún.\nCuando aceptes un match, podrás chatear aquí.',
            textAlign: TextAlign.center,
            style: TextStyle(color: SteamColors.textSec, fontSize: 12, height: 1.4),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: chatProv.conversaciones.length,
      separatorBuilder: (_, _) => const Divider(color: SteamColors.border, height: 1, indent: 56),
      itemBuilder: (context, index) {
        final chat = Map<String, dynamic>.from(chatProv.conversaciones[index] as Map);
        final nombre = ChatProvider.nombreOtro(chat);
        final idChat = chat['id_chat'];
        final ultimo = chat['ultimo_mensaje']?.toString() ?? 'Sin mensajes aún';
        final inicial = nombre.isNotEmpty ? nombre[0].toUpperCase() : '?';

        return ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          leading: CircleAvatar(
            radius: 16,
            backgroundColor: SteamColors.blue.withValues(alpha: 0.2),
            child: Text(
              inicial,
              style: const TextStyle(color: SteamColors.blue, fontWeight: FontWeight.w800, fontSize: 12),
            ),
          ),
          title: Text(
            nombre,
            style: const TextStyle(color: SteamColors.light, fontWeight: FontWeight.w700, fontSize: 13),
          ),
          subtitle: Text(
            ultimo,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: SteamColors.textSec, fontSize: 11),
          ),
          onTap: idChat == null
              ? null
              : () => onAbrirConversacion(
                    idChat is int ? idChat : int.parse(idChat.toString()),
                    nombre,
                  ),
        );
      },
    );
  }
}

class _ConversacionEmbebida extends StatefulWidget {
  final int chatId;
  final String otroNombre;

  const _ConversacionEmbebida({required this.chatId, required this.otroNombre});

  @override
  State<_ConversacionEmbebida> createState() => _ConversacionEmbebidaState();
}

class _ConversacionEmbebidaState extends State<_ConversacionEmbebida> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  int _ultimoConteo = 0;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollAlFinal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  Future<void> _enviar() async {
    final auth = context.read<AuthProvider>();
    final chatProv = context.read<ChatProvider>();
    final texto = _controller.text.trim();
    final miId = auth.usuario?['id'];
    if (texto.isEmpty || miId == null) return;

    final exito = await chatProv.enviarMensaje(
      widget.chatId,
      texto,
      miUserId: miId as int,
      miUsername: auth.usuario?['username']?.toString(),
    );
    if (!mounted) return;
    if (exito) {
      _controller.clear();
      _scrollAlFinal();
    }
  }

  bool _esMio(Map<String, dynamic> mensaje, int? miId) {
    if (miId == null) return false;
    return mensaje['id_emisor'].toString() == miId.toString();
  }

  @override
  Widget build(BuildContext context) {
    final chatProv = context.watch<ChatProvider>();
    final miId = context.watch<AuthProvider>().usuario?['id'];

    if (chatProv.mensajes.length != _ultimoConteo) {
      _ultimoConteo = chatProv.mensajes.length;
      if (!chatProv.cargandoMensajes) _scrollAlFinal();
    }

    return Column(
      children: [
        Expanded(
          child: chatProv.cargandoMensajes && chatProv.mensajes.isEmpty
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation(SteamColors.blue),
                  ),
                )
              : chatProv.mensajes.isEmpty
                  ? const Center(
                      child: Text(
                        'Aún no hay mensajes.\n¡Escribe el primero!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: SteamColors.textSec, fontSize: 12),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(10),
                      itemCount: chatProv.mensajes.length,
                      itemBuilder: (context, index) {
                        final mensaje = Map<String, dynamic>.from(chatProv.mensajes[index] as Map);
                        final esMio = _esMio(mensaje, miId);

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Align(
                            alignment: esMio ? Alignment.centerRight : Alignment.centerLeft,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 220),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                decoration: BoxDecoration(
                                  color: esMio ? SteamColors.blue : SteamColors.bgPanel,
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(12),
                                    topRight: const Radius.circular(12),
                                    bottomLeft: Radius.circular(esMio ? 12 : 3),
                                    bottomRight: Radius.circular(esMio ? 3 : 12),
                                  ),
                                  border: esMio ? null : Border.all(color: SteamColors.border),
                                ),
                                child: Text(
                                  mensaje['mensaje_chat'] ?? '',
                                  style: TextStyle(
                                    color: esMio ? Colors.white : SteamColors.light,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(8, 6, 6, 8),
          decoration: const BoxDecoration(
            color: SteamColors.bgPanel,
            border: Border(top: BorderSide(color: SteamColors.border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  minLines: 1,
                  maxLines: 3,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _enviar(),
                  style: const TextStyle(color: SteamColors.light, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Escribe un mensaje...',
                    hintStyle: const TextStyle(color: SteamColors.textSec, fontSize: 12),
                    filled: true,
                    fillColor: SteamColors.bgInput,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(SteamRadii.sm),
                      borderSide: const BorderSide(color: SteamColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(SteamRadii.sm),
                      borderSide: const BorderSide(color: SteamColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(SteamRadii.sm),
                      borderSide: const BorderSide(color: SteamColors.blue),
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send_rounded, color: SteamColors.blue),
                onPressed: _enviar,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
