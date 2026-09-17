// Columna derecha de escritorio (posición del wireframe): acceso rápido a
// chats. El panel de chat flotante (ver FloatingChat) cubre la conversación
// en sí; esta columna es solo la lista, igual que en el wireframe.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../features/chat/providers/chat_provider.dart';
import '../features/chat/screens/chat_conversation_screen.dart';
import '../theme/colors.dart';

class ChatsColumna extends StatelessWidget {
  const ChatsColumna({super.key});

  @override
  Widget build(BuildContext context) {
    final chatProv = context.watch<ChatProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'CHATS',
            style: TextStyle(
              color: SteamColors.textSec,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
        ),
        if (chatProv.cargandoLista && chatProv.conversaciones.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(SteamColors.blue),
              ),
            ),
          )
        else if (chatProv.conversaciones.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'No tienes conversaciones aún.',
              style: TextStyle(color: SteamColors.textSec, fontSize: 12),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              itemCount: chatProv.conversaciones.length,
              itemBuilder: (context, index) {
                final chat = Map<String, dynamic>.from(
                  chatProv.conversaciones[index] as Map,
                );
                final nombre = ChatProvider.nombreOtro(chat);
                final idChat = chat['id_chat'];
                final inicial = nombre.isNotEmpty ? nombre[0].toUpperCase() : '?';

                return ListTile(
                  dense: true,
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
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: SteamColors.light, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  onTap: idChat == null
                      ? null
                      : () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ChatConversationScreen(
                                chatId: idChat is int ? idChat : int.parse(idChat.toString()),
                                otroNombre: nombre,
                                otroUserId: ChatProvider.otroUserId(chat),
                              ),
                            ),
                          );
                        },
                );
              },
            ),
          ),
      ],
    );
  }
}
