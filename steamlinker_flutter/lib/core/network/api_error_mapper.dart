import 'package:dio/dio.dart';
import '../config/app_config.dart';

/// Mensajes de error de red/API unificados para toda la app.
class ApiErrorMapper {
  ApiErrorMapper._();

  static bool _isConnectionRefused(DioException e) {
    final parts = [
      e.message,
      e.error?.toString(),
      e.toString(),
    ];
    final text = parts.whereType<String>().join(' ').toLowerCase();
    return text.contains('connection refused') ||
        text.contains('failed host lookup') ||
        text.contains('network is unreachable') ||
        text.contains('connection failed') ||
        text.contains('socketexception');
  }

  static String resolve(DioException e, {required String fallback}) {
    final data = e.response?.data;
    if (data is Map && data['error'] != null) {
      final msg = data['error'].toString().trim();
      if (msg.isNotEmpty) return msg;
    }

    if (_isConnectionRefused(e) ||
        e.type == DioExceptionType.connectionError) {
      return AppConfig.connectionHelpMessage;
    }

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'La conexión tardó demasiado. Comprueba tu internet e inténtalo de nuevo.';
      case DioExceptionType.badCertificate:
        return 'Conexión no segura con el servidor (certificado inválido).';
      case DioExceptionType.cancel:
        return 'Operación cancelada.';
      case DioExceptionType.badResponse:
        final code = e.response?.statusCode;
        if (code == 401) return 'Sesión expirada. Vuelve a iniciar sesión.';
        if (code == 403) return 'No tienes permiso para esta acción.';
        if (code == 404) return 'Recurso no encontrado.';
        if (code != null && code >= 500) {
          return 'Error del servidor. Intenta más tarde.';
        }
        break;
      case DioExceptionType.connectionError:
        return AppConfig.connectionHelpMessage;
      case DioExceptionType.unknown:
        if (_isConnectionRefused(e)) {
          return AppConfig.connectionHelpMessage;
        }
        break;
    }

    return fallback;
  }
}
