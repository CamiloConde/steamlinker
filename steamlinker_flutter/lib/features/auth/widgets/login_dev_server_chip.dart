import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_error_mapper.dart';

/// Indicador compacto de servidor (esquina inferior derecha en login).
class LoginDevServerChip extends StatefulWidget {
  const LoginDevServerChip({super.key});

  @override
  State<LoginDevServerChip> createState() => _LoginDevServerChipState();
}

class _LoginDevServerChipState extends State<LoginDevServerChip> {
  bool _probando = false;

  Future<void> _probarConexion(BuildContext sheetContext) async {
    setState(() => _probando = true);
    try {
      final respuesta = await ApiClient.dio.get('/health');
      final data = respuesta.data;
      final db = data is Map ? data['database'] : null;
      if (!mounted || !sheetContext.mounted) return;
      Navigator.pop(sheetContext);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Servidor disponible. Ya puedes iniciar sesión.'
            '${db != null ? ' (base de datos: $db)' : ''}',
          ),
          backgroundColor: const Color(0xFF238636),
        ),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ApiErrorMapper.resolve(e, fallback: 'No se pudo conectar'),
            maxLines: 6,
          ),
          backgroundColor: Colors.red.shade800,
          duration: const Duration(seconds: 8),
        ),
      );
    } finally {
      if (mounted) setState(() => _probando = false);
    }
  }

  void _abrirDetalle() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF161B22),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            20 + MediaQuery.paddingOf(sheetContext).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Conexión con el servidor',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                AppConfig.loginServerHint,
                style: const TextStyle(
                  color: Color(0xFF8B949E),
                  fontSize: 12.5,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Dirección de la app',
                style: TextStyle(color: Color(0xFF6E7681), fontSize: 10),
              ),
              const SizedBox(height: 4),
              SelectableText(
                AppConfig.apiBaseUrl,
                style: const TextStyle(
                  color: Color(0xFF1A9FFF),
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: _probando ? null : () => _probarConexion(sheetContext),
                  icon: _probando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.wifi_tethering, size: 18),
                  label: const Text('Comprobar servidor'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (kReleaseMode) return const SizedBox.shrink();

    return Material(
      color: const Color(0xFF161B22).withValues(alpha: 0.92),
      elevation: 4,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: _abrirDetalle,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF1A9FFF).withValues(alpha: 0.35)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.dns_outlined, size: 16, color: Color(0xFF1A9FFF)),
              SizedBox(width: 6),
              Text(
                'Servidor',
                style: TextStyle(
                  color: Color(0xFF8B949E),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
