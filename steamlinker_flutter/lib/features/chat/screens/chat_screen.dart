import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../theme/colors.dart';
import '../../../widgets/desktop_body_width.dart';
import '../../../widgets/steam_app_bar.dart';
import '../providers/chat_provider.dart';
import 'chat_conversation_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  bool _inicializado = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_inicializado) {
      _inicializado = true;
      context.read<ChatProvider>().cargarConversaciones();
    }
  }

  void _abrirConversacion(Map<String, dynamic> chat) {
    final idChat = chat['id_chat'];
    if (idChat == null) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatConversationScreen(
          chatId: idChat is int ? idChat : int.parse(idChat.toString()),
          otroNombre: ChatProvider.nombreOtro(chat),
          otroUserId: ChatProvider.otroUserId(chat),
        ),
      ),
    ).then((_) {
      if (mounted) {
        context.read<ChatProvider>().cargarConversaciones();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final chatProv = context.watch<ChatProvider>();

    return Scaffold(
      backgroundColor: SteamColors.bgDeep,
      appBar: SteamAppBar(
        title: 'MENSAJES',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: SteamColors.blue),
            tooltip: 'Actualizar',
            onPressed: () => chatProv.cargarConversaciones(),
          ),
        ],
      ),
      body: DesktopBodyWidth(child: RefreshIndicator(
        color: SteamColors.blue,
        backgroundColor: SteamColors.bgDeep,
        onRefresh: () => chatProv.cargarConversaciones(),
        child: _buildBody(chatProv),
      )),
    );
  }

  Widget _buildBody(ChatProvider chatProv) {
    if (chatProv.cargandoLista && chatProv.conversaciones.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 120),
          Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(SteamColors.blue),
            ),
          ),
        ],
      );
    }

    if (chatProv.error != null && chatProv.conversaciones.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 80),
          Text(
            chatProv.error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red),
          ),
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: () => chatProv.cargarConversaciones(),
              child: const Text('Reintentar'),
            ),
          ),
        ],
      );
    }

    if (chatProv.conversaciones.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 80),
          Icon(Icons.chat_bubble_outline, size: 56, color: SteamColors.muted),
          SizedBox(height: 16),
          Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'No tienes conversaciones aún.\nCuando aceptes un match, podrás chatear aquí.',
                textAlign: TextAlign.center,
                style: TextStyle(color: SteamColors.textSec, height: 1.5),
              ),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: chatProv.conversaciones.length,
      separatorBuilder: (_, _) => const Divider(
        color: SteamColors.border,
        height: 1,
        indent: 72,
      ),
      itemBuilder: (context, index) {
        final chat = Map<String, dynamic>.from(
          chatProv.conversaciones[index] as Map,
        );
        final nombre = ChatProvider.nombreOtro(chat);
        final ultimo = chat['ultimo_mensaje']?.toString() ?? 'Sin mensajes aún';
        final inicial = nombre.isNotEmpty ? nombre[0].toUpperCase() : '?';

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: CircleAvatar(
            backgroundColor: SteamColors.blue.withValues(alpha: 0.2),
            child: Text(
              inicial,
              style: const TextStyle(
                color: SteamColors.blue,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          title: Text(
            nombre,
            style: const TextStyle(
              color: SteamColors.light,
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: Text(
            ultimo,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: SteamColors.textSec, fontSize: 12),
          ),
          trailing: const Icon(
            Icons.chevron_right,
            color: SteamColors.muted,
          ),
          onTap: () => _abrirConversacion(chat),
        );
      },
    );
  }
}
