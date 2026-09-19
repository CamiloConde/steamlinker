/// Códigos de país usados en perfil y publicaciones.
///
/// Lista ampliada a pedido del usuario -- antes solo tenía 5 países y no
/// cubría bien Latinoamérica, que es la región donde más se usa la app.
/// El mapa `_codigos` es la única fuente de verdad (nombre <-> código);
/// `nombres` sale de ahí para no mantener dos listas sincronizadas a mano.
/// Latinoamérica va primero en la lista (orden de aparición en el
/// selector) porque es donde más importa encontrarlo rápido.
class PaisUtil {
  PaisUtil._();

  static const todos = 'Todos';

  static const Map<String, String> _codigos = {
    // Latinoamérica primero
    'Colombia': 'CO',
    'México': 'MX',
    'Argentina': 'AR',
    'Chile': 'CL',
    'Perú': 'PE',
    'Ecuador': 'EC',
    'Venezuela': 'VE',
    'Bolivia': 'BO',
    'Paraguay': 'PY',
    'Uruguay': 'UY',
    'Costa Rica': 'CR',
    'Panamá': 'PA',
    'Guatemala': 'GT',
    'Honduras': 'HN',
    'El Salvador': 'SV',
    'Nicaragua': 'NI',
    'República Dominicana': 'DO',
    'Puerto Rico': 'PR',
    'Cuba': 'CU',
    // Resto
    'España': 'ES',
    'EE.UU.': 'US',
    'Canadá': 'CA',
    'Brasil': 'BR',
    'Reino Unido': 'GB',
    'Alemania': 'DE',
    'Francia': 'FR',
    'Italia': 'IT',
    'Portugal': 'PT',
  };

  static List<String> get nombres => _codigos.keys.toList(growable: false);

  static String nombreACodigo(String nombre) {
    return _codigos[nombre] ??
        (nombre.length <= 5 ? nombre : nombre.substring(0, 5));
  }

  static String codigoANombre(String? code) {
    if (code == null || code.isEmpty) return todos;
    final normalizado = code.toUpperCase();
    for (final entry in _codigos.entries) {
      if (entry.value == normalizado) return entry.key;
    }
    return code;
  }

  /// Emoji de bandera a partir del código ISO 3166-1 alpha-2 (ej. "CO" →
  /// 🇨🇴). No hace falta ninguna imagen ni dependencia nueva: cada letra
  /// A-Z tiene un "regional indicator symbol" en Unicode (U+1F1E6 = 'A'),
  /// y dos seguidos los renderiza como bandera casi cualquier
  /// navegador/SO moderno. Se usa junto al nombre del país, no en su
  /// lugar -- algunas banderas se confunden a simple vista.
  static String? codigoABandera(String? code) {
    if (code == null || code.length != 2) return null;
    final normalizado = code.toUpperCase();
    if (!RegExp(r'^[A-Z]{2}$').hasMatch(normalizado)) return null;
    const base = 0x1F1E6;
    final primero = base + (normalizado.codeUnitAt(0) - 'A'.codeUnitAt(0));
    final segundo = base + (normalizado.codeUnitAt(1) - 'A'.codeUnitAt(0));
    return String.fromCharCode(primero) + String.fromCharCode(segundo);
  }
}
