/// Escala de radios del sistema de diseño (dirección "Fiel a Steam", Fase 3).
///
/// Steam casi no redondea esquinas — cards, botones y tags del store/cliente
/// son prácticamente rectos. Usar estas constantes en vez de valores sueltos
/// como `BorderRadius.circular(6)`/`(10)` al tocar cada pantalla (Fase 5).
class SteamRadii {
  SteamRadii._();

  /// Estándar para cards, inputs, botones y tags. Úsalo por defecto.
  static const double sm = 2;

  /// Único caso con algo más de redondeo: avatares circulares y el logo.
  static const double avatar = 999;
}
