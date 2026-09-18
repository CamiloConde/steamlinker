// Cliente HTTP centralizado usando Dio

import 'package:dio/dio.dart';
import '../config/app_config.dart';
import '../storage/token_storage.dart';
import 'api_error_mapper.dart';

class ApiClient {
  static Future<void> Function()? onUnauthorized;

  // El access token ahora dura poco (1h, ver auth.js) -- cuando una
  // petición vuelve con 401, este interceptor intenta renovarlo con el
  // refresh token antes de rendirse y cerrar sesión. _refreshing evita
  // que dos peticiones que fallan casi a la vez disparen dos refresh en
  // paralelo (el refresh token rota en cada uso -- el segundo intento
  // fallaría igual si no reusaran el mismo resultado).
  static Future<String?>? _refreshing;

  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 20),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  static void init() {
    _dio.options.baseUrl = AppConfig.apiBaseUrl;
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await TokenStorage.obtenerToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          final path = error.requestOptions.path;
          final esAuthPublico = path.contains('/auth/login') ||
              path.contains('/auth/registro') ||
              path.contains('/auth/refresh');

          if (error.response?.statusCode == 401 && !esAuthPublico) {
            final nuevoToken = await _refrescarToken();
            if (nuevoToken != null) {
              try {
                final opts = error.requestOptions;
                opts.headers['Authorization'] = 'Bearer $nuevoToken';
                final respuesta = await _dio.fetch(opts);
                return handler.resolve(respuesta);
              } catch (_) {
                // Sigue fallando aunque el token se haya renovado -- deja
                // pasar el error original en vez de esconderlo.
              }
            } else if (onUnauthorized != null) {
              await onUnauthorized!();
            }
          }
          handler.next(error);
        },
      ),
    );
  }

  static Future<String?> _refrescarToken() {
    _refreshing ??= _hacerRefresh();
    return _refreshing!.whenComplete(() => _refreshing = null);
  }

  static Future<String?> _hacerRefresh() async {
    final refreshToken = await TokenStorage.obtenerRefreshToken();
    final usuarioId = await TokenStorage.obtenerUsuarioId();
    if (refreshToken == null || usuarioId == null) return null;

    try {
      final respuesta = await _dio.post(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
      );
      final nuevoToken = respuesta.data['token'] as String;
      final nuevoRefresh = respuesta.data['refreshToken'] as String;
      await TokenStorage.guardarToken(
        nuevoToken,
        usuarioId,
        refreshToken: nuevoRefresh,
      );
      return nuevoToken;
    } catch (_) {
      return null;
    }
  }

  static Dio get dio => _dio;

  /// Atajo para mensajes de error en providers.
  static String errorMessage(DioException e, {required String fallback}) =>
      ApiErrorMapper.resolve(e, fallback: fallback);
}
