// Maneja el estado del perfil de usuario
// Carga perfil, edita datos y gestiona juegos

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';

class PerfilProvider extends ChangeNotifier {
  bool _cargando = false;
  String? _error;
  Map<String, dynamic>? _perfil;
  List<dynamic> _juegos = [];
  Map<String, dynamic>? _privacidad;
  bool _descubrirCargando = false;
  List<dynamic> _usuariosDescubrir = [];

  bool get cargando => _cargando;
  bool get descubrirCargando => _descubrirCargando;
  List<dynamic> get usuariosDescubrir => _usuariosDescubrir;
  String? get error => _error;
  Map<String, dynamic>? get perfil => _perfil;
  List<dynamic> get juegos => _juegos;
  Map<String, dynamic>? get privacidad => _privacidad;

  Map<String, dynamic> _mapPerfil(Map<String, dynamic> raw, {bool actualizarPrivacidad = true}) {
    if (actualizarPrivacidad) {
      _privacidad = {
        'perfil_publico': raw['perfil_publico'] ?? true,
        'mostrar_biblioteca': raw['mostrar_biblioteca'] ?? true,
        'notificaciones_amigos': raw['notificaciones_amigos'] ?? true,
        'dos_factor': raw['dos_factor'] ?? false,
      };
    }

    return {
      'id': raw['id_usu'] ?? raw['id'],
      'username': raw['username_usu'] ?? raw['username'],
      'descrip': raw['descrip_usu'] ?? raw['descrip'],
      'pais': raw['pais_usu'] ?? raw['pais'],
      'repu': raw['repu_usu'] ?? raw['repu'] ?? 0,
      'totalrating': raw['totalrating_usu'] ?? raw['totalrating'],
      'tipo': raw['tipo_usu'] ?? raw['tipo'],
      'creadoen': raw['creadoen_usu'] ?? raw['creadoen'],
      'steam': raw['steam'],
    };
  }

  Map<String, dynamic> _mapJuego(Map<String, dynamic> raw) {
    return {
      'appid': raw['appid'],
      'nombre': raw['nom_jg'] ?? raw['nombre'] ?? raw['name'] ?? '',
      'headerimg': raw['headerimg_jg'] ?? raw['headerimg'] ?? '',
      'capsuleimg': raw['capsuleimg_jg'] ?? raw['capsuleimg'] ?? '',
      'horas': raw['horas_usujg'] ?? raw['horas'] ?? 0,
      'favorito': raw['esfav_usujg'] == true || raw['favorito'] == true,
    };
  }

  Future<Map<String, dynamic>?> cargarPerfilAjeno(int id) async {
    try {
      final respuesta = await ApiClient.dio.get('/perfil/$id');
      final raw = Map<String, dynamic>.from(respuesta.data);
      return {
        'perfil': _mapPerfil(raw, actualizarPrivacidad: false),
        'juegos': (raw['juegos'] as List<dynamic>? ?? [])
            .map((j) => _mapJuego(Map<String, dynamic>.from(j)))
            .toList(),
        'steam': raw['steam'],
        'steam_vinculado': raw['steam_vinculado'] == true || raw['steam'] != null,
        'biblioteca_oculta': raw['biblioteca_oculta'] == true,
      };
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) {
        _error = ApiClient.errorMessage(e, fallback: 'Perfil no disponible');
      } else {
        _error = ApiClient.errorMessage(e, fallback: 'Error al cargar perfil');
      }
      return null;
    }
  }

  Future<Map<String, dynamic>?> compararBiblioteca(int otroUserId) async {
    try {
      final respuesta = await ApiClient.dio.get('/perfil/comparar/$otroUserId');
      return Map<String, dynamic>.from(respuesta.data);
    } on DioException catch (e) {
      _error = ApiClient.errorMessage(e, fallback: 'Error al comparar bibliotecas');
      notifyListeners();
      return null;
    }
  }

  Future<void> descubrirUsuarios({
    String? tipo,
    String? pais,
    int? appid,
  }) async {
    _descubrirCargando = true;
    _error = null;
    notifyListeners();

    try {
      final params = <String, dynamic>{};
      if (tipo != null && tipo.isNotEmpty) params['tipo'] = tipo;
      if (pais != null && pais.isNotEmpty) params['pais'] = pais;
      if (appid != null) params['appid'] = appid;

      final respuesta = await ApiClient.dio.get(
        '/perfil/descubrir',
        queryParameters: params.isEmpty ? null : params,
      );
      _usuariosDescubrir = respuesta.data['usuarios'] ?? [];
      _descubrirCargando = false;
      notifyListeners();
    } on DioException catch (e) {
      _error = ApiClient.errorMessage(e, fallback: 'Error al descubrir usuarios');
      _descubrirCargando = false;
      notifyListeners();
    }
  }

  // Cargar perfil de cualquier usuario por id
  Future<void> cargarPerfil(int id) async {
    _cargando = true;
    _error = null;
    notifyListeners();

    try {
      final respuesta = await ApiClient.dio.get('/perfil/$id');
      _perfil = _mapPerfil(Map<String, dynamic>.from(respuesta.data));
      _juegos = (respuesta.data['juegos'] as List<dynamic>? ?? [])
          .map((j) => _mapJuego(Map<String, dynamic>.from(j)))
          .toList();
      _cargando = false;
      notifyListeners();
    } on DioException catch (e) {
      _error = ApiClient.errorMessage(e, fallback: 'Error al cargar perfil');
      _cargando = false;
      notifyListeners();
    }
  }

  // Editar descripcion y pais del perfil propio
  Future<bool> editarPerfil({String? descripcion, String? pais}) async {
    try {
      final respuesta = await ApiClient.dio.put('/perfil/editar', data: {
        'descripcion': descripcion,
        'pais': pais,
      });
      final perfilActualizado = _mapPerfil(Map<String, dynamic>.from(respuesta.data));
      _perfil = {...?_perfil, ...perfilActualizado};
      notifyListeners();
      return true;
    } on DioException catch (e) {
      _error = ApiClient.errorMessage(e, fallback: 'Error al editar perfil');
      notifyListeners();
      return false;
    }
  }

  // Buscar juegos en Steam Store API
  Future<List<dynamic>> buscarJuegos(String query) async {
    try {
      final respuesta = await ApiClient.dio.get(
        '/perfil/juegos/buscar',
        queryParameters: {'q': query},
      );
      return (respuesta.data['juegos'] as List<dynamic>? ?? [])
          .map((j) => _mapJuego(Map<String, dynamic>.from(j)))
          .toList();
    } on DioException {
      return [];
    }
  }

  Future<bool> vincularSteam(String steamId) async {
    try {
      await ApiClient.dio.post('/perfil/steam/vincular', data: {
        'steamid': steamId,
      });
      if (_perfil != null && _perfil!['id'] != null) {
        await cargarPerfil(_perfil!['id']);
      }
      return true;
    } on DioException catch (e) {
      _error = ApiClient.errorMessage(e, fallback: 'Error al vincular Steam');
      notifyListeners();
      return false;
    }
  }

  Future<String?> importarJuegosSteam() async {
    try {
      final respuesta = await ApiClient.dio.post('/perfil/steam/importar');
      if (_perfil != null && _perfil!['id'] != null) {
        await cargarPerfil(_perfil!['id']);
      }
      return respuesta.data['mensaje'] as String?;
    } on DioException catch (e) {
      _error = ApiClient.errorMessage(e, fallback: 'Error al importar juegos de Steam');
      notifyListeners();
      return null;
    }
  }

  Future<bool> desvincularSteam() async {
    try {
      await ApiClient.dio.delete('/perfil/steam/desvincular');
      if (_perfil != null && _perfil!['id'] != null) {
        await cargarPerfil(_perfil!['id']);
      }
      return true;
    } on DioException catch (e) {
      _error = ApiClient.errorMessage(e, fallback: 'Error al desvincular Steam');
      notifyListeners();
      return false;
    }
  }

  // Agregar juego al perfil
  Future<bool> agregarJuego(Map<String, dynamic> juego) async {
    try {
      await ApiClient.dio.post('/perfil/juegos/agregar', data: juego);
      if (_perfil != null && _perfil!['id'] != null) {
        await cargarPerfil(_perfil!['id']);
      }
      return true;
    } on DioException catch (e) {
      _error = ApiClient.errorMessage(e, fallback: 'Error al agregar juego');
      notifyListeners();
      return false;
    }
  }

  // Actualizar datos de un juego existente en el perfil
  Future<bool> actualizarJuego({
    required int appid,
    required String nombre,
    required String headerimg,
    required String capsuleimg,
    int? horas,
    bool? favorito,
  }) async {
    try {
      await ApiClient.dio.post('/perfil/juegos/agregar', data: {
        'appid': appid,
        'nombre': nombre,
        'headerimg': headerimg,
        'capsuleimg': capsuleimg,
        'horas': horas ?? 0,
        'favorito': favorito ?? false,
      });
      if (_perfil != null && _perfil!['id'] != null) {
        await cargarPerfil(_perfil!['id']);
      }
      return true;
    } on DioException catch (e) {
      _error = ApiClient.errorMessage(e, fallback: 'Error al actualizar juego');
      notifyListeners();
      return false;
    }
  }

  // Eliminar juego del perfil
  Future<bool> eliminarJuego(int appid) async {
    try {
      await ApiClient.dio.delete('/perfil/juegos/$appid');
      _juegos.removeWhere((j) => j['appid'] == appid);
      notifyListeners();
      return true;
    } on DioException catch (e) {
      _error = ApiClient.errorMessage(e, fallback: 'Error al eliminar juego');
      notifyListeners();
      return false;
    }
  }

  // Guardar ajustes de privacidad
  Future<bool> guardarPrivacidad({
    bool? perfilPublico,
    bool? mostrarBiblioteca,
    bool? notificacionesAmigos,
    bool? dosFactor,
  }) async {
    try {
      final respuesta = await ApiClient.dio.put(
        '/perfil/privacidad',
        data: {
          'perfil_publico': perfilPublico,
          'mostrar_biblioteca': mostrarBiblioteca,
          'notificaciones_amigos': notificacionesAmigos,
          'dos_factor': dosFactor,
        },
      );
      
      _privacidad = Map<String, dynamic>.from(respuesta.data['privacidad']);
      notifyListeners();
      return true;
    } on DioException catch (e) {
      _error = ApiClient.errorMessage(e, fallback: 'Error al guardar privacidad');
      notifyListeners();
      return false;
    }
  }
}
