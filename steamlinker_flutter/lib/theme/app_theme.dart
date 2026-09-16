import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colors.dart';

class SteamTheme {
  SteamTheme._();

  // Una sola familia en toda la app (Source Sans 3, sustituto abierto de la
  // Motiva Sans propietaria de Steam) en vez de una fuente display + una de
  // texto — así es como el propio Steam lo hace. Ver HANDOFF.md sección 12.
  static TextTheme get _textTheme =>
      GoogleFonts.sourceSans3TextTheme(ThemeData.dark().textTheme);

  static ThemeData get theme => ThemeData(
        scaffoldBackgroundColor: SteamColors.bgDeep,
        textTheme: _textTheme,
        fontFamily: GoogleFonts.sourceSans3().fontFamily,
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
                ? Colors.white
                : SteamColors.muted,
          ),
          trackColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
                ? SteamColors.teal
                : SteamColors.border,
          ),
        ),
        colorScheme: const ColorScheme.dark(
          primary: SteamColors.blue,
          surface: SteamColors.bgCard,
        ),
      );
}
