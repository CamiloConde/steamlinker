import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/config/app_config.dart';
import '../../../theme/colors.dart';
import '../../../theme/radii.dart';

/// Bloque visible solo para cuentas con rol administrador.
class AdminPanelSection extends StatelessWidget {
  const AdminPanelSection({super.key});

  Future<void> _abrirPanel(BuildContext context) async {
    final uri = Uri.parse(AppConfig.adminPanelUrl);
    try {
      final ok = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!context.mounted) return;
      if (!ok) {
        _mostrarAyuda(context, uri.toString());
      }
    } catch (_) {
      if (!context.mounted) return;
      _mostrarAyuda(context, uri.toString());
    }
  }

  void _mostrarAyuda(BuildContext context, String url) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'No se pudo abrir el navegador. Copia el enlace:\n$url',
          maxLines: 4,
        ),
        action: SnackBarAction(
          label: 'Copiar',
          onPressed: () {
            Clipboard.setData(ClipboardData(text: url));
          },
        ),
        duration: const Duration(seconds: 6),
      ),
    );
  }

  void _copiarEnlace(BuildContext context) {
    final url = AppConfig.adminPanelUrl;
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Enlace del panel copiado al portapapeles'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final url = AppConfig.adminPanelUrl;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF3D2E14).withValues(alpha: 0.9),
            SteamColors.bgCard,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(SteamRadii.sm),
        border: Border.all(color: SteamColors.orange.withValues(alpha: 0.55), width: 1.2),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: SteamColors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(SteamRadii.sm),
                  border: Border.all(color: SteamColors.orange, width: 1.2),
                ),
                child: const Icon(
                  Icons.admin_panel_settings_outlined,
                  color: SteamColors.orange,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Zona de administración',
                      style: TextStyle(
                        color: SteamColors.light,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Solo para tu cuenta de administrador',
                      style: TextStyle(
                        color: SteamColors.orange,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Gestiona la comunidad desde el panel web: revisa reportes, '
            'modera publicaciones, consulta estadísticas y administra cuentas de usuario. '
            'Inicia sesión allí con el mismo correo y contraseña que usas en la app.',
            style: TextStyle(
              color: SteamColors.textSec,
              fontSize: 12.5,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          SelectableText(
            url,
            style: const TextStyle(
              color: Color(0xFFE6A817),
              fontSize: 11,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: () => _abrirPanel(context),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('Abrir panel administrativo'),
              style: ElevatedButton.styleFrom(
                backgroundColor: SteamColors.orange,
                foregroundColor: SteamColors.bgDeep,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(SteamRadii.sm),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: () => _copiarEnlace(context),
              child: const Text(
                'Copiar enlace del panel',
                style: TextStyle(color: SteamColors.muted, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
