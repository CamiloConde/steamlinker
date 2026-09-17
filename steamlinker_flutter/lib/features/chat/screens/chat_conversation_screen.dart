import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../theme/colors.dart';
import '../../../theme/radii.dart';
import '../../../widgets/steam_app_bar.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../widgets/chat_context_banner.dart';

class ChatConversationScreen extends StatefulWidget {
  final int chatId;
  final String otroNombre;
  final int? otroUserId;

  const ChatConversationScreen({
    super.key,
    required this.chatId,
    required this.otroNombre,
    this.otroUserId,
  });

  @override
  State<ChatConversationScreen> createState() => _ChatConversationScreenState();
}

class _ChatConversationScreenState extends State<ChatConversationScreen> {
  final TextEditingController _mensajeController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  int _ultimoConteoMensajes = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final chatProv = context.read<ChatProvider>();
      await Future.wait([
        chatProv.cargarMensajes(widget.chatId),
        if (chatProv.conversaciones.isEmpty) chatProv.cargarConversaciones(),
      ]);
      if (!mounted) return;
      _scrollAlFinal();
    });
  }

  @override
  void dispose() {
    _mensajeController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollAlFinal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  Future<void> _recargarMensajes() async {
    await context.read<ChatProvider>().cargarMensajes(widget.chatId);
    _scrollAlFinal();
  }

  Future<void> _enviarMensaje() async {
    final auth = context.read<AuthProvider>();
    final chatProv = context.read<ChatProvider>();
    final texto = _mensajeController.text.trim();
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
      _mensajeController.clear();
      _scrollAlFinal();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(chatProv.error ?? 'No se pudo enviar el mensaje')),
      );
    }
  }

  bool _esMio(Map<String, dynamic> mensaje, int? miId) {
    if (miId == null) return false;
    final emisor = mensaje['id_emisor'];
    if (emisor == miId) return true;
    return emisor.toString() == miId.toString();
  }

  @override
  Widget build(BuildContext context) {
    final chatProv = context.watch<ChatProvider>();
    final miId = context.watch<AuthProvider>().usuario?['id'];

    if (chatProv.mensajes.length != _ultimoConteoMensajes) {
      _ultimoConteoMensajes = chatProv.mensajes.length;
      if (!chatProv.cargandoMensajes) {
        _scrollAlFinal();
      }
    }

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          context.read<ChatProvider>().salirConversacion();
          context.read<ChatProvider>().cargarConversaciones();
        }
      },
      child: Scaffold(
        backgroundColor: SteamColors.bgDeep,
        appBar: SteamAppBar(
          title: widget.otroNombre.toUpperCase(),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: SteamColors.blue),
              tooltip: 'Actualizar',
              onPressed: _recargarMensajes,
            ),
          ],
        ),
        body: Column(
          children: [
            ChatContextBanner(conversacion: chatProv.conversacionPorId(widget.chatId)),
            Expanded(
              child: chatProv.cargandoMensajes && chatProv.mensajes.isEmpty
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation(SteamColors.blue),
                      ),
                    )
                  : chatProv.mensajes.isEmpty
                      ? RefreshIndicator(
                          color: SteamColors.blue,
                          onRefresh: _recargarMensajes,
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: const [
                              SizedBox(height: 120),
                              Center(
                                child: Text(
                                  'Aún no hay mensajes.\n¡Escribe el primero!',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: SteamColors.textSec),
                                ),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          color: SteamColors.blue,
                          onRefresh: _recargarMensajes,
                          child: ListView.builder(
                            controller: _scrollController,
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 16,
                            ),
                            itemCount: chatProv.mensajes.length,
                            itemBuilder: (context, index) {
                              final mensaje = Map<String, dynamic>.from(
                                chatProv.mensajes[index] as Map,
                              );
                              final esMio = _esMio(mensaje, miId);

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Align(
                                  alignment: esMio
                                      ? Alignment.centerRight
                                      : Alignment.centerLeft,
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxWidth:
                                          MediaQuery.of(context).size.width *
                                              0.78,
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: esMio
                                            ? SteamColors.blue
                                            : SteamColors.bgPanel,
                                        borderRadius: BorderRadius.only(
                                          topLeft: const Radius.circular(14),
                                          topRight: const Radius.circular(14),
                                          bottomLeft: Radius.circular(
                                            esMio ? 14 : 4,
                                          ),
                                          bottomRight: Radius.circular(
                                            esMio ? 4 : 14,
                                          ),
                                        ),
                                        border: esMio
                                            ? null
                                            : Border.all(
                                                color: SteamColors.border,
                                              ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          if (!esMio) ...[
                                            Text(
                                              mensaje['emisor_username']
                                                      ?.toString() ??
                                                  widget.otroNombre,
                                              style: const TextStyle(
                                                color: SteamColors.blue,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                          ],
                                          Text(
                                            mensaje['mensaje_chat'] ?? '',
                                            style: TextStyle(
                                              color: esMio
                                                  ? Colors.white
                                                  : SteamColors.light,
                                              fontSize: 14,
                                              height: 1.35,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
            ),
            _Composer(
              controller: _mensajeController,
              enviando: chatProv.enviando,
              onEnviar: _enviarMensaje,
            ),
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final bool enviando;
  final VoidCallback onEnviar;

  const _Composer({
    required this.controller,
    required this.enviando,
    required this.onEnviar,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        decoration: const BoxDecoration(
          color: SteamColors.bgPanel,
          border: Border(top: BorderSide(color: SteamColors.border)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onEnviar(),
                style: const TextStyle(color: SteamColors.light),
                decoration: InputDecoration(
                  hintText: 'Escribe un mensaje...',
                  hintStyle: const TextStyle(color: SteamColors.textSec),
                  filled: true,
                  fillColor: SteamColors.bgInput,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
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
            const SizedBox(width: 8),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: SteamColors.blue,
                foregroundColor: Colors.white,
                disabledBackgroundColor: SteamColors.bgCard,
                disabledForegroundColor: SteamColors.muted,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(SteamRadii.sm),
                ),
              ),
              onPressed: enviando ? null : onEnviar,
              icon: enviando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded, size: 18),
              label: Text(
                enviando ? '...' : 'Enviar',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
