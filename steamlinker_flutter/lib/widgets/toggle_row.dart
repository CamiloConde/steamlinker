import 'package:flutter/material.dart';
import '../theme/colors.dart';

class ToggleRow extends StatelessWidget {
  final String title;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool showDivider;
  /// El toggle se guarda pero ningún flujo del backend lo usa todavía para
  /// condicionar comportamiento real (a diferencia de p. ej. "Perfil
  /// público", que sí filtra resultados en /perfil/descubrir). Se marca así
  /// en vez de ocultarlo, para no fingir que "guardar" no hizo nada.
  final bool decorativo;

  const ToggleRow({
    super.key,
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
    this.showDivider = true,
    this.decorativo = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: SteamColors.light,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (decorativo) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: SteamColors.muted.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'DECORATIVA · NO FUNCIONAL POR AHORA',
                          style: TextStyle(
                            color: SteamColors.muted,
                            fontSize: 8.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(
                    color: SteamColors.textSec,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ]),
      ),
      if (showDivider)
        const Divider(color: Color(0x302A3F5A), height: 1),
    ]);
  }
}
