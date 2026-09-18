import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/config/app_config.dart';
import '../../../theme/colors.dart';
import '../../../theme/radii.dart';
import '../../../widgets/steam_card.dart';
import '../../../widgets/steam_toast.dart';

/// "Apoya el proyecto": pedido explícitamente por el usuario para el día 1
/// del lanzamiento (ver HANDOFF.md, "Nivel 1.5"), modelado como el enlace de
/// Ko-fi que usa SteamDB. Sin cuenta real todavía, el botón queda deshabilitado
/// y marcado "Próximamente" — no se fabrica un destino falso.
class ApoyarProyectoCard extends StatelessWidget {
  const ApoyarProyectoCard({super.key});

  bool get _tieneEnlace => AppConfig.kofiUrl.isNotEmpty;

  Future<void> _abrir(BuildContext context) async {
    final uri = Uri.tryParse(AppConfig.kofiUrl);
    if (uri == null) return;
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!context.mounted || ok) return;
      _avisar(context, uri.toString());
    } catch (_) {
      if (context.mounted) _avisar(context, uri.toString());
    }
  }

  void _avisar(BuildContext context, String url) {
    showSteamToast(
      context,
      'No se pudo abrir el navegador. Copia el enlace:\n$url',
      SteamColors.orange,
      duration: const Duration(seconds: 6),
    );
  }

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
            'SteamMatch es un proyecto independiente. Si te sirve, puedes '
            'invitarnos un café para ayudarnos a seguir mejorándolo.',
            style: TextStyle(color: SteamColors.textSec, fontSize: 12.5, height: 1.4),
          ),
          const SizedBox(height: 12),
          if (_tieneEnlace)
            ElevatedButton.icon(
              onPressed: () => _abrir(context),
              icon: const Icon(Icons.local_cafe_outlined, size: 18),
              label: const Text('Invitar un café'),
              style: ElevatedButton.styleFrom(
                backgroundColor: SteamColors.yellow,
                foregroundColor: SteamColors.bgDeep,
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: SteamColors.bgInput,
                borderRadius: BorderRadius.circular(SteamRadii.sm),
                border: Border.all(color: SteamColors.border),
              ),
              alignment: Alignment.center,
              child: const Text(
                'Próximamente',
                style: TextStyle(
                  color: SteamColors.muted,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
