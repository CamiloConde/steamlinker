import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../theme/colors.dart';
import '../../../widgets/steam_buttons.dart';

/// Pantalla 404: se muestra cuando GoRouter no encuentra la ruta pedida
/// (URL mal escrita, enlace roto, o un deep link viejo). Una sola llamada
/// a la acción clara — volver a Inicio — en vez de dejar al usuario en el
/// error genérico sin estilo que pinta GoRouter por defecto.
class NotFoundScreen extends StatelessWidget {
  final String? rutaPedida;

  const NotFoundScreen({super.key, this.rutaPedida});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SteamColors.bgDeep,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.explore_off_outlined,
                    size: 64,
                    color: SteamColors.blue,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    '404',
                    style: TextStyle(
                      color: SteamColors.light,
                      fontSize: 40,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'No encontramos esta página',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: SteamColors.light,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    rutaPedida != null && rutaPedida!.isNotEmpty
                        ? 'El enlace "$rutaPedida" no existe o ya no está disponible.'
                        : 'El enlace que seguiste no existe o ya no está disponible.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: SteamColors.textSec,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 28),
                  SteamButtonPrimary(
                    label: 'Volver a Inicio',
                    icon: Icons.home_outlined,
                    onTap: (_) => context.go('/home'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
