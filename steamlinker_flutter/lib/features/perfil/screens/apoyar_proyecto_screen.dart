import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/config/app_config.dart';
import '../../../theme/colors.dart';
import '../../../theme/radii.dart';
import '../../../widgets/steam_app_bar.dart';
import '../../../widgets/steam_toast.dart';
import '../../../widgets/desktop_body_width.dart';

/// "Apoya el proyecto", con opciones según país -- pedido explícito del
/// usuario tras comparar con cómo lo hace SteamDB. Colombia usa una llave
/// Bre-B (sistema de pagos inmediatos interoperable, sin exponer número de
/// cuenta/cédula/celular); el resto del mundo sigue usando Ko-fi. Ver
/// HANDOFF.md, "Nivel 1.5".
class ApoyarProyectoScreen extends StatelessWidget {
  const ApoyarProyectoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SteamColors.bgDeep,
      appBar: const SteamAppBar(title: 'APOYA EL PROYECTO'),
      body: DesktopBodyWidth(
        maxWidth: 600,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'SteamMatch es gratis, y así se va a quedar. Es un '
                'proyecto independiente -- si te sirve y quieres darnos '
                'una mano, se agradece un montón, pero nunca es '
                'obligatorio ni vas a necesitar pagar nada para usarlo.',
                style: TextStyle(
                  color: SteamColors.textSec,
                  fontSize: 13.5,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              _SeccionPais(
                bandera: '🇨🇴',
                titulo: 'Colombia',
                child: _tieneBreB
                    ? _TarjetaLlaveBreB(llave: AppConfig.brebKey)
                    : const _Proximamente(),
              ),
              const SizedBox(height: 20),
              _SeccionPais(
                bandera: '🌍',
                titulo: 'Otros países',
                child: _tieneKofi
                    ? const _TarjetaKofi()
                    : const _Proximamente(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool get _tieneBreB => AppConfig.brebKey.isNotEmpty;
  bool get _tieneKofi => AppConfig.kofiUrl.isNotEmpty;
}

class _SeccionPais extends StatelessWidget {
  final String bandera;
  final String titulo;
  final Widget child;

  const _SeccionPais({
    required this.bandera,
    required this.titulo,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(bandera, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Text(
              titulo,
              style: const TextStyle(
                color: SteamColors.light,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

class _TarjetaLlaveBreB extends StatelessWidget {
  final String llave;
  const _TarjetaLlaveBreB({required this.llave});

  void _copiar(BuildContext context) {
    Clipboard.setData(ClipboardData(text: llave));
    showSteamToast(context, 'Llave copiada', SteamColors.green);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SteamColors.bgCard,
        borderRadius: BorderRadius.circular(SteamRadii.sm),
        border: Border.all(color: SteamColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Transfiere desde la app de tu banco o billetera (Nequi, '
            'Bancolombia, Davivienda, cualquiera que tenga Bre-B) '
            'buscando "Transferir con llave" o "Bre-B", con esta llave:',
            style: TextStyle(color: SteamColors.textSec, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () => _copiar(context),
            borderRadius: BorderRadius.circular(SteamRadii.sm),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: SteamColors.bgInput,
                borderRadius: BorderRadius.circular(SteamRadii.sm),
                border: Border.all(color: SteamColors.blue),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      llave,
                      style: const TextStyle(
                        color: SteamColors.light,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  const Icon(Icons.copy, size: 18, color: SteamColors.blue),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TarjetaKofi extends StatelessWidget {
  const _TarjetaKofi();

  Future<void> _abrir(BuildContext context) async {
    final uri = Uri.tryParse(AppConfig.kofiUrl);
    if (uri == null) return;
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!context.mounted || ok) return;
      _avisar(context);
    } catch (_) {
      if (context.mounted) _avisar(context);
    }
  }

  void _avisar(BuildContext context) {
    showSteamToast(
      context,
      'No se pudo abrir el navegador. Copia el enlace:\n${AppConfig.kofiUrl}',
      SteamColors.orange,
      duration: const Duration(seconds: 6),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SteamColors.bgCard,
        borderRadius: BorderRadius.circular(SteamRadii.sm),
        border: Border.all(color: SteamColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Invítanos un café por Ko-fi (tarjeta, PayPal y otros medios '
            'internacionales).',
            style: TextStyle(color: SteamColors.textSec, fontSize: 13),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => _abrir(context),
            icon: const Icon(Icons.local_cafe_outlined, size: 18),
            label: const Text('Invitar un café'),
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

class _Proximamente extends StatelessWidget {
  const _Proximamente();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14),
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
    );
  }
}
