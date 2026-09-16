import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/radii.dart';

void showSteamToast(BuildContext context, String message, Color color) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(children: [
        Icon(Icons.check_circle_outline, color: color, size: 17),
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
      duration: const Duration(seconds: 3),
    ),
  );
}

void showSteamToastWithMessenger(
  ScaffoldMessengerState messenger,
  String message,
  Color color,
) {
  messenger.showSnackBar(
    SnackBar(
      content: Row(children: [
        Icon(Icons.check_circle_outline, color: color, size: 17),
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
      duration: const Duration(seconds: 3),
    ),
  );
}
