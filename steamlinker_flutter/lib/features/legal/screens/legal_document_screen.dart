import 'package:flutter/material.dart';
import '../../../theme/colors.dart';
import '../../../widgets/steam_app_bar.dart';

/// Armazón compartido por Aviso Legal y Política de Privacidad: mismo
/// título/fecha/estilo, el contenido real lo da cada pantalla.
class LegalDocumentScreen extends StatelessWidget {
  final String titulo;
  final String actualizado;
  final List<Widget> secciones;

  const LegalDocumentScreen({
    super.key,
    required this.titulo,
    required this.actualizado,
    required this.secciones,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SteamColors.bgDeep,
      appBar: SteamAppBar(title: titulo, showBack: true),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Última actualización: $actualizado',
            style: const TextStyle(color: SteamColors.muted, fontSize: 11.5),
          ),
          const SizedBox(height: 20),
          ...secciones,
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class LegalSeccion extends StatelessWidget {
  final String titulo;
  final String cuerpo;

  const LegalSeccion({super.key, required this.titulo, required this.cuerpo});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: const TextStyle(
              color: SteamColors.light,
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            cuerpo,
            style: const TextStyle(
              color: SteamColors.textSec,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
