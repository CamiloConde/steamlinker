import 'package:flutter/material.dart';
import '../../../theme/colors.dart';
import '../../../widgets/steam_card.dart';
import '../screens/apoyar_proyecto_screen.dart';

/// "Apoya el proyecto": pedido explícitamente por el usuario para el día 1
/// del lanzamiento (ver HANDOFF.md, "Nivel 1.5"). Ya no abre Ko-fi
/// directo -- lleva a `ApoyarProyectoScreen`, que separa Colombia (llave
/// Bre-B) de otros países (Ko-fi), pedido tras comparar con SteamDB.
class ApoyarProyectoCard extends StatelessWidget {
  const ApoyarProyectoCard({super.key});

  @override
  Widget build(BuildContext context) {
    return SteamCard(
      icon: Icons.favorite_border_rounded,
      title: 'Apoya el proyecto',
      accent: SteamColors.yellow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SteamMatch es gratis y un proyecto independiente. Si te '
            'sirve, puedes ayudarnos a seguir mejorándolo.',
            style: TextStyle(color: SteamColors.textSec, fontSize: 12.5, height: 1.4),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ApoyarProyectoScreen()),
            ),
            icon: const Icon(Icons.favorite_rounded, size: 18),
            label: const Text('Ver cómo apoyar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: SteamColors.yellow,
              foregroundColor: SteamColors.bgDeep,
            ),
          ),
        ],
      ),
    );
  }
}
