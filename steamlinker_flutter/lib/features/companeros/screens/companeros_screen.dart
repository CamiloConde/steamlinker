import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../theme/colors.dart';
import '../../../widgets/desktop_body_width.dart';
import '../../../widgets/steam_app_bar.dart';
import '../../amistad/screens/amistad_screen.dart';
import '../../descubrir/screens/descubrir_gamers_screen.dart';
import '../../publicaciones/providers/publicaciones_provider.dart';
import '../../publicaciones/screens/publicaciones_screen.dart';

/// Pestaña "Compañeros": fusiona Amigos + Buscar + Avisos en 3 sub-pestañas
/// (ver HANDOFF.md: reorganización de IA en 4 pestañas).
class CompanerosScreen extends StatefulWidget {
  const CompanerosScreen({super.key});

  @override
  State<CompanerosScreen> createState() => _CompanerosScreenState();
}

class _CompanerosScreenState extends State<CompanerosScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SteamColors.bgDeep,
      appBar: const SteamAppBar(title: 'COMPAÑEROS'),
      body: DesktopBodyWidth(child: Column(
        children: [
          Container(
            color: SteamColors.bgPanel,
            child: TabBar(
              controller: _tabs,
              indicatorColor: SteamColors.blue,
              indicatorWeight: 2,
              labelColor: SteamColors.blue,
              unselectedLabelColor: SteamColors.muted,
              labelStyle: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
              tabs: const [
                Tab(text: 'Amigos'),
                Tab(text: 'Buscar'),
                Tab(text: 'Avisos'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                const AmistadScreen(embebida: true),
                const DescubrirGamersScreen(embebida: true),
                ChangeNotifierProvider(
                  create: (_) => PublicacionesProvider(),
                  child: const PublicacionesScreen(
                    tipoFiltroFijo: 'busco_companero',
                    embebida: true,
                  ),
                ),
              ],
            ),
          ),
        ],
      )),
    );
  }
}
