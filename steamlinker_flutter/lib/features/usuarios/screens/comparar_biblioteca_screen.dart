import 'package:flutter/material.dart';
import '../../../theme/colors.dart';
import '../../../theme/radii.dart';
import '../../../widgets/steam_app_bar.dart';

class CompararBibliotecaScreen extends StatelessWidget {
  final Map<String, dynamic> resultado;

  const CompararBibliotecaScreen({super.key, required this.resultado});

  @override
  Widget build(BuildContext context) {
    final comunes = (resultado['commonGames'] as List<dynamic>?) ?? [];
    final totalA = resultado['totalA'] ?? 0;
    final totalB = resultado['totalB'] ?? 0;
    final commonCount = resultado['commonCount'] ?? comunes.length;
    final otro = resultado['otro_username'] ?? 'Usuario';
    final fuente = resultado['fuente']?.toString() ?? 'local';
    final esSteam = fuente == 'steam';
    final pctA = totalA > 0 ? ((commonCount / totalA) * 100).round() : 0;
    final pctB = totalB > 0 ? ((commonCount / totalB) * 100).round() : 0;

    return Scaffold(
      backgroundColor: SteamColors.bgDeep,
      appBar: const SteamAppBar(title: 'JUEGOS EN COMÚN'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: SteamColors.bgPanel,
              borderRadius: BorderRadius.circular(SteamRadii.sm),
              border: Border.all(color: SteamColors.border),
            ),
            child: Column(
              children: [
                Text(
                  'Tú y $otro',
                  style: const TextStyle(
                    color: SteamColors.light,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: (esSteam ? SteamColors.teal : SteamColors.blue)
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(SteamRadii.sm),
                  ),
                  child: Text(
                    esSteam ? 'Datos en vivo · Steam API' : 'Datos del perfil',
                    style: TextStyle(
                      color: esSteam ? SteamColors.teal : SteamColors.blue,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '$commonCount juego${commonCount == 1 ? '' : 's'} en común',
                  style: const TextStyle(
                    color: SteamColors.blue,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tu biblioteca: $totalA juegos ($pctA% coinciden)\n'
                  'Su biblioteca: $totalB juegos ($pctB% coinciden)',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: SteamColors.textSec,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (comunes.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  esSteam
                      ? 'No hay juegos en común según Steam.\nComprueba que ambos perfiles de Steam sean públicos.'
                      : 'No hay juegos en común en los perfiles.\nAgrega más juegos o vincula Steam para comparar en vivo.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: SteamColors.textSec),
                ),
              ),
            )
          else
            ...comunes.map((j) {
              final juego = Map<String, dynamic>.from(j as Map);
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: SteamColors.bgCard,
                  borderRadius: BorderRadius.circular(SteamRadii.sm),
                  border: Border.all(color: SteamColors.border),
                ),
                child: Row(
                  children: [
                    Semantics(
                      image: true,
                      label: 'Carátula de ${juego['nombre'] ?? 'juego'}',
                      child: Container(
                        width: 56,
                        height: 32,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(SteamRadii.sm),
                          color: SteamColors.bgPanel,
                          image:
                              juego['headerimg']?.toString().isNotEmpty == true
                              ? DecorationImage(
                                  image: NetworkImage(juego['headerimg']),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            juego['nombre'] ?? 'Juego',
                            style: const TextStyle(
                              color: SteamColors.light,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            'Tú: ${juego['misHoras'] ?? 0}h · $otro: ${juego['susHoras'] ?? 0}h',
                            style: const TextStyle(
                              color: SteamColors.textSec,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
