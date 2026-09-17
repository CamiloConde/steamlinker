import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';

class CalificacionesProvider extends ChangeNotifier {
  String? _error;
  bool _cargandoResenas = false;
  String? _errorResenas;
  List<dynamic> _resenas = [];
  double _promedioResenas = 0;
  int _totalResenas = 0;

  String? get error => _error;
  bool get cargandoResenas => _cargandoResenas;
  String? get errorResenas => _errorResenas;
  List<dynamic> get resenas => _resenas;
  double get promedioResenas => _promedioResenas;
  int get totalResenas => _totalResenas;

  Future<void> cargarDeUsuario(int userId) async {
    _cargandoResenas = true;
    _errorResenas = null;
    notifyListeners();

    try {
      final respuesta = await ApiClient.dio.get('/calificaciones/usuario/$userId');
      _resenas = respuesta.data['calificaciones'] ?? [];
      // Postgres devuelve AVG() como string (numeric), no como JSON number.
      _promedioResenas = double.tryParse('${respuesta.data['promedio']}') ?? 0;
      _totalResenas = respuesta.data['total'] as int? ?? _resenas.length;
      _cargandoResenas = false;
      notifyListeners();
    } on DioException catch (e) {
      _errorResenas = ApiClient.errorMessage(e, fallback: 'Error al cargar reseñas');
      _cargandoResenas = false;
      notifyListeners();
    }
  }

  Future<bool> crear({
    required int idMatch,
    required int idCalificado,
    required double estrellas,
    bool? confiable,
    String? comentario,
  }) async {
    _error = null;
    try {
      await ApiClient.dio.post('/calificaciones/crear', data: {
        'id_match': idMatch,
        'id_calificado': idCalificado,
        'estrellas': estrellas,
        'confiable': confiable,
        'comentario': comentario,
      });
      return true;
    } on DioException catch (e) {
      _error = ApiClient.errorMessage(e, fallback: 'Error al calificar');
      notifyListeners();
      return false;
    }
  }
}
