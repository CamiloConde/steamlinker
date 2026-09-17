// Maneja el estado del chat y mensajes

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';

class ChatProvider extends ChangeNotifier {
  bool _cargandoLista = false;
  bool _cargandoMensajes = false;
  bool _enviando = false;
  String? _error;
  List<dynamic> _conversaciones = [];
  List<dynamic> _mensajes = [];
  int? _chatActivo;

  bool get cargandoLista => _cargandoLista;
  bool get cargandoMensajes => _cargandoMensajes;
  bool get enviando => _enviando;
  bool get cargando => _cargandoLista || _cargandoMensajes;
  String? get error => _error;
  List<dynamic> get conversaciones => _conversaciones;
  List<dynamic> get mensajes => _mensajes;
  int? get chatActivo => _chatActivo;

  static String nombreOtro(Map<String, dynamic> chat) {
    final otro = chat['otro_username'];
    if (otro != null && otro.toString().isNotEmpty) {
      return otro.toString();
    }
    return chat['username_participante2']?.toString() ??
        chat['username_participante1']?.toString() ??
        'Usuario';
  }

  static int? otroUserId(Map<String, dynamic> chat) {
    final id = chat['otro_id'];
    if (id is int) return id;
    return int.tryParse(id?.toString() ?? '');
  }

  Map<String, dynamic>? conversacionPorId(int idChat) {
    for (final c in _conversaciones) {
      final chat = Map<String, dynamic>.from(c as Map);
      if (chat['id_chat'] == idChat) return chat;
    }
    return null;
  }

  Future<void> cargarConversaciones() async {
    _cargandoLista = true;
    _error = null;
    notifyListeners();

    try {
      final respuesta = await ApiClient.dio.get('/chat/conversaciones');
      _conversaciones = respuesta.data['conversaciones'] ?? [];
      _cargandoLista = false;
      notifyListeners();
    } on DioException catch (e) {
      _error = ApiClient.errorMessage(e, fallback: 'Error al cargar conversaciones');
      _cargandoLista = false;
      notifyListeners();
    }
  }

  Future<void> cargarMensajes(int idChat, {bool silencioso = false}) async {
    _chatActivo = idChat;
    if (!silencioso) {
      _cargandoMensajes = true;
      _error = null;
      notifyListeners();
    }

    try {
      final respuesta = await ApiClient.dio.get('/chat/$idChat/mensajes');
      _mensajes = respuesta.data['mensajes'] ?? [];
      _cargandoMensajes = false;
      notifyListeners();
    } on DioException catch (e) {
      _error = ApiClient.errorMessage(e, fallback: 'Error al cargar mensajes');
      _cargandoMensajes = false;
      notifyListeners();
    }
  }

  void salirConversacion() {
    _chatActivo = null;
    _mensajes = [];
    _cargandoMensajes = false;
    notifyListeners();
  }

  Future<bool> enviarMensaje(
    int idChat,
    String mensaje, {
    required int miUserId,
    String? miUsername,
  }) async {
    _enviando = true;
    notifyListeners();

    try {
      final respuesta = await ApiClient.dio.post('/chat/$idChat/mensaje', data: {
        'mensaje': mensaje,
      });
      final data = Map<String, dynamic>.from(respuesta.data as Map);
      if (!data.containsKey('emisor_username') && miUsername != null) {
        data['emisor_username'] = miUsername;
      }
      data['id_emisor'] = data['id_emisor'] ?? miUserId;
      _mensajes.add(data);
      _enviando = false;
      notifyListeners();
      return true;
    } on DioException catch (e) {
      _error = ApiClient.errorMessage(e, fallback: 'Error al enviar mensaje');
      _enviando = false;
      notifyListeners();
      return false;
    }
  }

  Future<int?> iniciarChat(int idReceptor) async {
    try {
      final respuesta = await ApiClient.dio.post('/chat/iniciar', data: {
        'id_receptor': idReceptor,
      });
      await cargarConversaciones();
      final chat = respuesta.data['chat'];
      return chat['id_chat'] as int?;
    } on DioException catch (e) {
      _error = ApiClient.errorMessage(e, fallback: 'Error al iniciar chat');
      notifyListeners();
      return null;
    }
  }
}
