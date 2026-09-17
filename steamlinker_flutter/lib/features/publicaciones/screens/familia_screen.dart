import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/publicaciones_provider.dart';
import 'publicaciones_screen.dart';

/// Pestaña "Familia": feed de busco_familia + busco_miembros (ver
/// HANDOFF.md: reorganización de IA en 4 pestañas).
///
/// Usa su propio PublicacionesProvider en vez del global de main.dart
/// porque Familia, Compañeros y Comunidad quedan montadas simultáneamente
/// en el IndexedStack de ResponsiveShell — compartir el provider global
/// causaba que sus filtros (filtroTipo) se pisaran entre sí.
class FamiliaScreen extends StatelessWidget {
  const FamiliaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => PublicacionesProvider(),
      child: const PublicacionesScreen(
        tipoFiltroFijo: 'busco_familia,busco_miembros',
        tituloFijo: 'FAMILIA',
      ),
    );
  }
}
