import 'package:flutter/material.dart';
import '../theme/colors.dart';

/// Insignia STEAM/MANUAL para un juego -- indica si Steam lo confirma
/// directamente o si el usuario lo agregó a mano (por ejemplo, biblioteca
/// compartida de Familia de Steam, que la API pública no puede verificar
/// pero sigue siendo un juego real del usuario).
class BadgeOrigenJuego extends StatelessWidget {
  final bool esSteam;
  const BadgeOrigenJuego({super.key, required this.esSteam});

  @override
  Widget build(BuildContext context) {
    final color = esSteam ? SteamColors.teal : SteamColors.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(31),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withAlpha(102)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            esSteam ? Icons.verified : Icons.edit_outlined,
            size: 11,
            color: color,
          ),
          const SizedBox(width: 3),
          Text(
            esSteam ? 'STEAM' : 'MANUAL',
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}
