// Maneja el estado de publicaciones y busqueda con filtros

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../core/constants/publicacion_constants.dart';
import '../../../core/network/api_client.dart';

class PublicacionesProvider extends ChangeNotifier {
  bool _cargando = false;
  String? _error;
  List<dynamic> _publicaciones = [];
  int _total = 0;

  String? _filtroTipo;
  String? _filtroPais;
  int? _filtroAppid;
  String? _filtroJuegoNombre;
  String _filtroOrden = PublicacionConstants.ordenRecientes;

  bool get cargando => _cargando;
  String? get error => _error;
  List<dynamic> get publicaciones => _publicaciones;
  int get total => _total;

  String? get filtroTipo => _filtroTipo;
  String? get filtroPais => _filtroPais;
  int? get filtroAppid => _filtroAppid;
  String? get filtroJuegoNombre => _filtroJuegoNombre;
  String get filtroOrden => _filtroOrden;

  bool get tieneFiltrosActivos =>
      (_filtroTipo != null && _filtroTipo!.isNotEmpty) ||
      (_filtroPais != null && _filtroPais!.isNotEmpty) ||
      _filtroAppid != null ||
      _filtroOrden != PublicacionConstants.ordenRecientes;

  Future<void> setFiltros({
    String? tipo,
    String? pais,
    int? appid,
    String? juegoNombre,
    String? orden,
  }) async {
    _filtroTipo = tipo != null && tipo.isEmpty ? null : tipo;
    _filtroPais = pais != null && pais.isEmpty ? null : pais;
    _filtroAppid = appid;
    _filtroJuegoNombre = juegoNombre;
    if (orden != null) _filtroOrden = orden;
    await buscar();
  }

  Future<void> limpiarFiltros() async {
    _filtroTipo = null;
    _filtroPais = null;
    _filtroAppid = null;
    _filtroJuegoNombre = null;
    _filtroOrden = PublicacionConstants.ordenRecientes;
    await buscar();
  }

  Future<void> buscar() async {
    _cargando = true;
    _error = null;
    notifyListeners();

    try {
      final params = <String, dynamic>{'orden': _filtroOrden};
      if (_filtroTipo != null && _filtroTipo!.isNotEmpty) {
        params['tipo'] = _filtroTipo;
      }
      if (_filtroPais != null && _filtroPais!.isNotEmpty) {
        params['pais'] = _filtroPais;
      }
      if (_filtroAppid != null) params['appid'] = _filtroAppid;

      final respuesta = await ApiClient.dio.get(
        '/publicaciones/buscar',
        queryParameters: params,
      );

      _publicaciones = respuesta.data['publicaciones'] ?? [];
      _total = respuesta.data['total'] ?? 0;
      _cargando = false;
      notifyListeners();
    } on DioException catch (e) {
      _error = ApiClient.errorMessage(e, fallback: 'Error al buscar publicaciones');
      _cargando = false;
      notifyListeners();
    }
  }

  Future<bool> crear({
    required String tipo,
    required String titulo,
    String? descripcion,
    String? pais,
    int? cuposTotales,
    List<Map<String, dynamic>> juegos = const [],
  }) async {
    _error = null;
    try {
      await ApiClient.dio.post('/publicaciones/crear', data: {
        'tipo': tipo,
        'titulo': titulo,
        'descripcion': descripcion,
        'pais': pais,
        'cupos_totales': ?cuposTotales,
        'juegos': juegos,
      });
      await buscar();
      return true;
    } on DioException catch (e) {
      _error = ApiClient.errorMessage(e, fallback: 'Error al crear publicacion');
      notifyListeners();
      return false;
    }
  }

  // Antes no había forma de corregir una publicación ya creada -- había
  // que borrarla y volver a hacerla. Pedido explícito del usuario.
  Future<bool> editar({
    required int id,
    required String titulo,
    String? descripcion,
    String? pais,
    int? cuposTotales,
    List<Map<String, dynamic>>? juegos,
  }) async {
    _error = null;
    try {
      await ApiClient.dio.put('/publicaciones/$id/editar', data: {
        'titulo': titulo,
        'descripcion': descripcion,
        'pais': pais,
        'cupos_totales': ?cuposTotales,
        'juegos': ?juegos,
      });
      await buscar();
      return true;
    } on DioException catch (e) {
      _error = ApiClient.errorMessage(e, fallback: 'Error al editar publicación');
      notifyListeners();
      return false;
    }
  }

  Map<String, dynamic>? _detalle;
  bool _cargandoDetalle = false;

  Map<String, dynamic>? get detalle => _detalle;
  bool get cargandoDetalle => _cargandoDetalle;

  Future<Map<String, dynamic>?> cargarPorId(int id) async {
    _cargandoDetalle = true;
    _error = null;
    notifyListeners();

    try {
      final respuesta = await ApiClient.dio.get('/publicaciones/$id');
      _detalle = Map<String, dynamic>.from(respuesta.data as Map);
      _cargandoDetalle = false;
      notifyListeners();
      return _detalle;
    } on DioException catch (e) {
      _error = ApiClient.errorMessage(e, fallback: 'Error al cargar publicación');
      _detalle = null;
      _cargandoDetalle = false;
      notifyListeners();
      return null;
    }
  }

  void limpiarDetalle() {
    _detalle = null;
    _comentarios = [];
    notifyListeners();
  }

  List<dynamic> _comentarios = [];
  bool _cargandoComentarios = false;
  bool _enviandoComentario = false;

  List<dynamic> get comentarios => _comentarios;
  bool get cargandoComentarios => _cargandoComentarios;
  bool get enviandoComentario => _enviandoComentario;

  Future<void> cargarComentarios(int idPubli) async {
    _cargandoComentarios = true;
    notifyListeners();

    try {
      final respuesta = await ApiClient.dio.get('/publicaciones/$idPubli/comentarios');
      _comentarios = respuesta.data['comentarios'] ?? [];
      _cargandoComentarios = false;
      notifyListeners();
    } on DioException catch (e) {
      _error = ApiClient.errorMessage(e, fallback: 'Error al cargar comentarios');
      _cargandoComentarios = false;
      notifyListeners();
    }
  }

  Future<bool> enviarComentario(
    int idPubli,
    String texto, {
    int? idPadre,
  }) async {
    _enviandoComentario = true;
    notifyListeners();

    try {
      final respuesta = await ApiClient.dio.post(
        '/publicaciones/$idPubli/comentarios',
        data: {
          'texto': texto,
          'id_padre': ?idPadre,
        },
      );
      _comentarios = [..._comentarios, respuesta.data];
      _enviandoComentario = false;
      notifyListeners();
      return true;
    } on DioException catch (e) {
      _error = ApiClient.errorMessage(e, fallback: 'Error al comentar');
      _enviandoComentario = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> cerrar(int id) async {
    try {
      await ApiClient.dio.put('/publicaciones/$id/cerrar');
      _publicaciones.removeWhere((p) => p['id_publi'] == id);
      _total--;
      notifyListeners();
      return true;
    } on DioException catch (e) {
      _error = ApiClient.errorMessage(e, fallback: 'Error al cerrar publicacion');
      notifyListeners();
      return false;
    }
  }
}
