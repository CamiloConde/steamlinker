import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colors.dart';

/// Transición uniforme en todas las plataformas: sin esto, Flutter elige el
/// estilo nativo según `defaultTargetPlatform` (zoom estilo Android, slide
/// estilo iOS...), lo que en Flutter Web depende del user-agent detectado y
/// puede sentirse inconsistente entre navegadores. Un fade + leve subida es
/// sutil y funciona igual de bien en escritorio que en móvil.
class _FadeThroughTransitionsBuilder extends PageTransitionsBuilder {
  const _FadeThroughTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeOut);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.02),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}

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
        (s) =>
            s.contains(WidgetState.selected) ? Colors.white : SteamColors.muted,
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
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: _FadeThroughTransitionsBuilder(),
        TargetPlatform.iOS: _FadeThroughTransitionsBuilder(),
        TargetPlatform.linux: _FadeThroughTransitionsBuilder(),
        TargetPlatform.macOS: _FadeThroughTransitionsBuilder(),
        TargetPlatform.windows: _FadeThroughTransitionsBuilder(),
        TargetPlatform.fuchsia: _FadeThroughTransitionsBuilder(),
      },
    ),
  );
}
