import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../features/reportes/providers/reportes_provider.dart';
import '../theme/colors.dart';
import 'steam_toast.dart';

Future<bool?> mostrarReportarUsuarioDialog(
  BuildContext context, {
  required String nombreUsuario,
  required int idReportado,
}) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => _ReportarDialog(
      nombreUsuario: nombreUsuario,
      idReportado: idReportado,
    ),
  );
}

class _ReportarDialog extends StatefulWidget {
  final String nombreUsuario;
  final int idReportado;

  const _ReportarDialog({
    required this.nombreUsuario,
    required this.idReportado,
  });

  @override
  State<_ReportarDialog> createState() => _ReportarDialogState();
}

class _ReportarDialogState extends State<_ReportarDialog> {
  final _controller = TextEditingController();
  bool _enviando = false;

  static const _motivosRapidos = [
    'Comportamiento tóxico',
    'Spam o publicaciones engañosas',
    'Acoso',
    'Suplantación de identidad',
    'Otro',
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    final motivo = _controller.text.trim();
    if (motivo.length < 10) {
      showSteamToast(context, 'Describe el motivo (mín. 10 caracteres)', SteamColors.orange);
      return;
    }

    setState(() => _enviando = true);
    final exito = await context.read<ReportesProvider>().crear(
      idReportado: widget.idReportado,
      motivo: motivo,
    );
    if (!mounted) return;
    setState(() => _enviando = false);

    if (exito) {
      Navigator.pop(context, true);
    } else {
      showSteamToast(
        context,
        context.read<ReportesProvider>().error ?? 'No se pudo enviar',
        Colors.red,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: SteamColors.bgPanel,
      title: Text(
        'Reportar a ${widget.nombreUsuario}',
        style: const TextStyle(color: SteamColors.light, fontSize: 16),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'El equipo revisará tu reporte. Sé específico.',
              style: TextStyle(color: SteamColors.textSec, fontSize: 12),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _motivosRapidos.map((m) {
                return ActionChip(
                  label: Text(m, style: const TextStyle(fontSize: 11)),
                  backgroundColor: SteamColors.bgCard,
                  labelStyle: const TextStyle(color: SteamColors.light),
                  side: const BorderSide(color: SteamColors.border),
                  onPressed: () => _controller.text = m,
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              maxLines: 4,
              maxLength: 500,
              style: const TextStyle(color: SteamColors.light, fontSize: 13),
              decoration: const InputDecoration(
                hintText: 'Motivo del reporte...',
                hintStyle: TextStyle(color: SteamColors.muted),
                filled: true,
                fillColor: SteamColors.bgInput,
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _enviando ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _enviando ? null : _enviar,
          style: ElevatedButton.styleFrom(
            backgroundColor: SteamColors.red,
            foregroundColor: Colors.white,
          ),
          child: Text(_enviando ? 'Enviando...' : 'Enviar reporte'),
        ),
      ],
    );
  }
}
