import 'package:flutter/foundation.dart';

/// URL del API.
///
/// Emulador Android (debug/profile): [http://10.0.2.2:3000]
/// Móvil físico: `flutter run --dart-define=API_BASE_URL=http://TU_IP:3000`
/// Release: `--dart-define=API_BASE_URL=https://api.tudominio.com`
class AppConfig {
  AppConfig._();

  static const String _apiFromEnv = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static const String _adminPanelFromEnv = String.fromEnvironment(
    'ADMIN_PANEL_URL',
    defaultValue: '',
  );

  /// Enlace de donaciones ("Apoya el proyecto") — ver HANDOFF.md sección
  /// "Nivel 1.5". Puede sobreescribirse con
  /// `--dart-define=KOFI_URL=https://ko-fi.com/otro_usuario` si algún día
  /// cambia, pero por defecto ya apunta a la cuenta real.
  static const String kofiUrl = String.fromEnvironment(
    'KOFI_URL',
    defaultValue: 'https://ko-fi.com/camiko31',
  );

  static const int localPort = 3000;

  static bool get isProduction => kReleaseMode;

  static String get apiBaseUrl {
    if (_apiFromEnv.isNotEmpty) {
      return _apiFromEnv.replaceAll(RegExp(r'/$'), '');
    }

    if (kIsWeb) {
      return 'http://localhost:$localPort';
    }

    // Android (emulador o móvil sin dart-define): 10.0.2.2 = tu PC desde el emulador.
    // En el navegador del PC sigues usando localhost:3000 — es la misma máquina, otra dirección.
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:$localPort';
    }

    if (kDebugMode || kProfileMode) {
      return 'http://127.0.0.1:$localPort';
    }

    return 'http://localhost:$localPort';
  }

  /// Panel web de administración (mismo host que el API + `/admin/`).
  static String get adminPanelUrl {
    if (_adminPanelFromEnv.isNotEmpty) {
      final u = _adminPanelFromEnv.replaceAll(RegExp(r'/$'), '');
      return u.endsWith('/admin') ? '$u/' : '$u/admin/';
    }
    return '${apiBaseUrl.replaceAll(RegExp(r'/$'), '')}/admin/';
  }

  /// Texto del recuadro de servidor en la pantalla de login (modo desarrollo).
  static String get loginServerHint {
    if (kIsWeb) {
      return 'Antes de entrar, inicia el backend en tu computadora '
          '(carpeta steamlinker_back → npm run dev).';
    }
    if (defaultTargetPlatform == TargetPlatform.android &&
        apiBaseUrl.contains('10.0.2.2')) {
      return 'Antes de entrar, el backend debe estar encendido en tu PC. '
          'Esta dirección conecta la app con tu computadora; no la modifiques '
          'si usas el emulador de Android.';
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'Antes de entrar, inicia el backend en tu PC y comprueba que el '
          'teléfono y la computadora estén en la misma red Wi‑Fi.';
    }
    return 'Antes de entrar, inicia el backend en tu computadora '
        '(steamlinker_back → npm run dev) y deja este enlace tal como está.';
  }

  /// Mensaje corto para pantallas de login cuando falla la conexión.
  static String get connectionHelpMessage =>
      'No pudimos contactar el servidor ($apiBaseUrl).\n\n'
      '• Abre una terminal en steamlinker_back y ejecuta: npm run dev\n'
      '• En el navegador de tu PC prueba: http://localhost:$localPort/health\n'
      '• Si usas un móvil físico, configura la IP de tu PC con API_BASE_URL';
}
