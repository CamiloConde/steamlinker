import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/radii.dart';

/// El ícono siempre era un check verde sin importar el color pasado — un
/// toast de error en rojo mostraba de todos modos una palomita de éxito.
/// Se elige según el color para que el ícono coincida con lo que dice el
/// mensaje, sin tener que tocar los ~30 sitios que ya llaman a
/// showSteamToast con SteamColors.red/orange/green o Colors.red.
IconData _iconoSteamToast(Color color) {
  if (color == SteamColors.red || color == Colors.red) {
    return Icons.error_outline;
  }
  if (color == SteamColors.orange || color == Colors.orange) {
    return Icons.warning_amber_rounded;
  }
  if (color == SteamColors.green) {
    return Icons.check_circle_outline;
  }
  return Icons.info_outline;
}

SnackBar _steamToastSnackBar(
  String message,
  Color color, {
  SnackBarAction? action,
  Duration duration = const Duration(seconds: 3),
}) {
  return SnackBar(
    content: Row(children: [
      Icon(_iconoSteamToast(color), color: color, size: 17),
      const SizedBox(width: 9),
      Flexible(
        child: Text(
          message,
          style: const TextStyle(
            color: SteamColors.light,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    ]),
    backgroundColor: SteamColors.bgPanel,
    behavior: SnackBarBehavior.floating,
    margin: const EdgeInsets.all(16),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(SteamRadii.sm),
      side: BorderSide(color: color),
    ),
    duration: duration,
    action: action,
  );
}

void showSteamToast(
  BuildContext context,
  String message,
  Color color, {
  SnackBarAction? action,
  Duration duration = const Duration(seconds: 3),
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    _steamToastSnackBar(message, color, action: action, duration: duration),
  );
}

void showSteamToastWithMessenger(
  ScaffoldMessengerState messenger,
  String message,
  Color color, {
  SnackBarAction? action,
  Duration duration = const Duration(seconds: 3),
}) {
  messenger.showSnackBar(
    _steamToastSnackBar(message, color, action: action, duration: duration),
  );
}
