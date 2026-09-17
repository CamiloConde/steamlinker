import 'package:flutter/material.dart';
import '../theme/colors.dart';

class CalificarDialogResult {
  final double estrellas;
  final bool confiable;
  final String? comentario;

  CalificarDialogResult({
    required this.estrellas,
    required this.confiable,
    this.comentario,
  });
}

Future<CalificarDialogResult?> mostrarCalificarDialog(
  BuildContext context, {
  required String nombreUsuario,
}) {
  return showDialog<CalificarDialogResult>(
    context: context,
    builder: (ctx) => _CalificarDialog(nombreUsuario: nombreUsuario),
  );
}

class _CalificarDialog extends StatefulWidget {
  final String nombreUsuario;

  const _CalificarDialog({required this.nombreUsuario});

  @override
  State<_CalificarDialog> createState() => _CalificarDialogState();
}

class _CalificarDialogState extends State<_CalificarDialog> {
  double _estrellas = 4;
  bool _confiable = true;
  final _comentarioController = TextEditingController();

  @override
  void dispose() {
    _comentarioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: SteamColors.bgPanel,
      title: Text(
        'Calificar a ${widget.nombreUsuario}',
        style: const TextStyle(color: SteamColors.light, fontSize: 16),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${_estrellas.toStringAsFixed(1)} / 5',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: SteamColors.blue,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            Slider(
              value: _estrellas,
              min: 1,
              max: 5,
              divisions: 8,
              activeColor: SteamColors.blue,
              onChanged: (v) => setState(() => _estrellas = v),
            ),
            CheckboxListTile(
              value: _confiable,
              onChanged: (v) => setState(() => _confiable = v ?? false),
              title: const Text(
                'Usuario confiable',
                style: TextStyle(color: SteamColors.light, fontSize: 13),
              ),
              activeColor: SteamColors.blue,
              contentPadding: EdgeInsets.zero,
            ),
            TextField(
              controller: _comentarioController,
              maxLines: 3,
              style: const TextStyle(color: SteamColors.light),
              decoration: const InputDecoration(
                labelText: 'Comentario (opcional)',
                filled: true,
                fillColor: SteamColors.bgInput,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar', style: TextStyle(color: SteamColors.muted)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: SteamColors.blue,
            foregroundColor: Colors.white,
          ),
          onPressed: () {
            Navigator.pop(
              context,
              CalificarDialogResult(
                estrellas: _estrellas,
                confiable: _confiable,
                comentario: _comentarioController.text.trim().isEmpty
                    ? null
                    : _comentarioController.text.trim(),
              ),
            );
          },
          child: const Text('Enviar'),
        ),
      ],
    );
  }
}
