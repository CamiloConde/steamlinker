import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:provider/provider.dart';
import '../../../core/network/api_client.dart';
import '../../../theme/colors.dart';
import '../../../widgets/drop_field.dart';
import '../../../widgets/steam_app_bar.dart';
import '../../../widgets/steam_buttons.dart';
import '../../../widgets/steam_toast.dart';
import '../../auth/providers/auth_provider.dart';

const _tiposEtiquetas = ['Sugerencia', 'Queja', 'Reportar un error', 'Otro'];
const _tiposValores = ['sugerencia', 'queja', 'error', 'otro'];

class ContactoScreen extends StatefulWidget {
  const ContactoScreen({super.key});

  @override
  State<ContactoScreen> createState() => _ContactoScreenState();
}

class _ContactoScreenState extends State<ContactoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _mensajeCtrl = TextEditingController();
  // Honeypot: invisible para una persona real, un bot que autocompleta
  // todos los <input> del formulario cae aquí. Ver contacto.js en el backend.
  final _sitioWebCtrl = TextEditingController();
  String _tipoEtiqueta = _tiposEtiquetas.first;
  bool _enviando = false;
  bool _precargado = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_precargado) {
      _precargado = true;
      final usuario = context.read<AuthProvider>().usuario;
      if (usuario != null) {
        _nombreCtrl.text = usuario['username']?.toString() ?? '';
        _emailCtrl.text = usuario['email']?.toString() ?? '';
      }
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _emailCtrl.dispose();
    _mensajeCtrl.dispose();
    _sitioWebCtrl.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _enviando = true);
    try {
      await ApiClient.dio.post('/contacto', data: {
        'nombre': _nombreCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'tipo': _tiposValores[_tiposEtiquetas.indexOf(_tipoEtiqueta)],
        'mensaje': _mensajeCtrl.text.trim(),
        'sitio_web': _sitioWebCtrl.text,
      });
      if (!mounted) return;
      showSteamToast(context, 'Mensaje enviado, ¡gracias por escribirnos!', SteamColors.green);
      Navigator.of(context).pop();
    } on DioException catch (e) {
      if (!mounted) return;
      showSteamToast(
        context,
        ApiClient.errorMessage(e, fallback: 'No se pudo enviar el mensaje'),
        SteamColors.red,
      );
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SteamColors.bgDeep,
      appBar: const SteamAppBar(title: 'CONTACTO', showBack: true),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              '¿Sugerencia, queja o algo no funciona? Cuéntanos.',
              style: TextStyle(
                color: SteamColors.light,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Leemos todos los mensajes. Si nos dejas tu correo, te '
              'respondemos si hace falta.',
              style: TextStyle(color: SteamColors.textSec, fontSize: 12.5, height: 1.4),
            ),
            const SizedBox(height: 24),
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _nombreCtrl,
                    style: const TextStyle(color: SteamColors.light),
                    decoration: const InputDecoration(
                      labelText: 'Nombre',
                      filled: true,
                      fillColor: SteamColors.bgInput,
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Escribe tu nombre' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: SteamColors.light),
                    decoration: const InputDecoration(
                      labelText: 'Correo',
                      filled: true,
                      fillColor: SteamColors.bgInput,
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Escribe tu correo';
                      if (!v.contains('@')) return 'Correo no válido';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  DropField(
                    label: 'Tipo',
                    value: _tipoEtiqueta,
                    items: _tiposEtiquetas,
                    onChanged: (v) => setState(() => _tipoEtiqueta = v),
                  ),
                  TextFormField(
                    controller: _mensajeCtrl,
                    maxLines: 6,
                    style: const TextStyle(color: SteamColors.light),
                    decoration: const InputDecoration(
                      labelText: 'Mensaje',
                      hintText: 'Cuéntanos con detalle...',
                      filled: true,
                      fillColor: SteamColors.bgInput,
                    ),
                    validator: (v) {
                      if (v == null || v.trim().length < 10) {
                        return 'Cuéntanos un poco más (mínimo 10 caracteres)';
                      }
                      return null;
                    },
                  ),
                  // Honeypot fuera de la vista real, pero presente en el árbol
                  // de widgets para que un bot que rellena todo lo encuentre.
                  Offstage(
                    child: TextFormField(controller: _sitioWebCtrl),
                  ),
                  const SizedBox(height: 20),
                  SteamButtonPrimary(
                    label: _enviando ? 'Enviando...' : 'Enviar mensaje',
                    icon: Icons.send_outlined,
                    onTap: _enviando ? null : (_) => _enviar(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
