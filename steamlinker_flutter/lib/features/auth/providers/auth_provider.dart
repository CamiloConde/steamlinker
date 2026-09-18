// Maneja el estado de autenticacion de toda la app
// Login, registro y cierre de sesion

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/token_storage.dart';

class AuthProvider extends ChangeNotifier {
  bool _cargando = false;
  String? _error;
  bool _autenticado = false;
  Map<String, dynamic>? _usuario;

  bool get cargando => _cargando;
  String? get error => _error;
  bool get autenticado => _autenticado;
  Map<String, dynamic>? get usuario => _usuario;

  // Verificar si hay sesion activa al iniciar la app
  Future<void> verificarSesion() async {
    final hayToken = await TokenStorage.haySession();
    if (hayToken) {
      try {
        final respuesta = await ApiClient.dio.get('/auth/perfil');
        _usuario = respuesta.data;
        _autenticado = true;
      } catch (e) {
        await TokenStorage.eliminarToken();
        _autenticado = false;
      }
    }
    notifyListeners();
  }

  // Registrar un nuevo usuario
  Future<bool> registrar({
    required String username,
    required String email,
    required String password,
    String? pais,
  }) async {
    _cargando = true;
    _error = null;
    notifyListeners();

    try {
      final respuesta = await ApiClient.dio.post('/auth/registro', data: {
        'username': username,
        'email': email,
        'password': password,
        'pais': pais,
      });

      final token = respuesta.data['token'];
      final refreshToken = respuesta.data['refreshToken'];
      final usuario = respuesta.data['usuario'];

      await TokenStorage.guardarToken(token, usuario['id'], refreshToken: refreshToken);
      _usuario = usuario;
      _autenticado = true;
      _cargando = false;
      notifyListeners();
      return true;

    } on DioException catch (e) {
      _error = ApiClient.errorMessage(e, fallback: 'Error al registrarse');
      _cargando = false;
      notifyListeners();
      return false;
    }
  }

  // Iniciar sesion
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _cargando = true;
    _error = null;
    notifyListeners();

    try {
      final respuesta = await ApiClient.dio.post('/auth/login', data: {
        'email': email,
        'password': password,
      });

      final token = respuesta.data['token'];
      final refreshToken = respuesta.data['refreshToken'];
      final usuario = respuesta.data['usuario'];

      await TokenStorage.guardarToken(token, usuario['id'], refreshToken: refreshToken);
      _usuario = usuario;
      _autenticado = true;
      _cargando = false;
      notifyListeners();
      return true;

    } on DioException catch (e) {
      _error = ApiClient.errorMessage(e, fallback: 'Error al iniciar sesion');
      _cargando = false;
      notifyListeners();
      return false;
    }
  }

  // Cerrar sesion (limpia token y estado; usar confirmarYCerrarSesion en UI para ir al login)
  Future<void> logout() async {
    // Revoca la sesión del lado del servidor antes de borrar el token
    // local -- si no, el refresh token sigue vivo en `sesiones` y en
    // teoría podría reusarse hasta que expire solo (30 días). Es
    // "mejor esfuerzo": si falla (sin red, etc.) igual se cierra sesión
    // local, no vale la pena bloquear el logout por esto.
    final refreshToken = await TokenStorage.obtenerRefreshToken();
    if (refreshToken != null) {
      try {
        await ApiClient.dio.post('/auth/logout', data: {'refreshToken': refreshToken});
      } catch (_) {}
    }
    await TokenStorage.eliminarToken();
    _usuario = null;
    _autenticado = false;
    _error = null;
    _cargando = false;
    notifyListeners();
  }

  // Cambiar la contraseña del usuario autenticado
  Future<bool> cambiarContrasena({
    required String contrasenaActual,
    required String nuevaContrasena,
  }) async {
    _cargando = true;
    _error = null;
    notifyListeners();

    try {
      await ApiClient.dio.put('/auth/cambiar-contrasena', data: {
        'currentPassword': contrasenaActual,
        'newPassword': nuevaContrasena,
      });
      _cargando = false;
      notifyListeners();
      return true;
    } on DioException catch (e) {
      _error = ApiClient.errorMessage(e, fallback: 'Error al cambiar contrasena');
      _cargando = false;
      notifyListeners();
      return false;
    }
  }

  // Eliminar la cuenta del usuario autenticado
  Future<bool> eliminarCuenta() async {
    _cargando = true;
    _error = null;
    notifyListeners();

    try {
      await ApiClient.dio.delete('/auth/cuenta');
      await logout();
      _cargando = false;
      return true;
    } on DioException catch (e) {
      _error = ApiClient.errorMessage(e, fallback: 'Error al eliminar cuenta');
      _cargando = false;
      notifyListeners();
      return false;
    }
  }

  void actualizarUsuario(Map<String, dynamic> datos) {
    _usuario = {...?_usuario, ...datos};
    notifyListeners();
  }
}