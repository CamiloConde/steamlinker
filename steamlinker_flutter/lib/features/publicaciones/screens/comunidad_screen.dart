import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/publicaciones_provider.dart';
import 'publicaciones_screen.dart';

/// Pestaña "Comunidad": feed de publicaciones tipo "otro" (ver HANDOFF.md:
/// reorganización de IA en 4 pestañas).
///
/// Provider propio por la misma razón que FamiliaScreen (ver ese archivo).
class ComunidadScreen extends StatelessWidget {
  const ComunidadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => PublicacionesProvider(),
      child: const PublicacionesScreen(
        tipoFiltroFijo: 'otro',
        tituloFijo: 'COMUNIDAD',
      ),
    );
  }
}
