import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../theme/colors.dart';
import '../../../theme/radii.dart';
import '../../../widgets/accesos_rapidos_panel.dart';
import '../../../widgets/chats_columna.dart';
import '../../../widgets/desktop_body_width.dart';
import '../../../widgets/steam_app_bar.dart';
import '../../../widgets/steam_buttons.dart';
import '../../../widgets/usuario_card.dart';
import '../../chat/providers/chat_provider.dart';
import '../../descubrir/screens/descubrir_gamers_screen.dart';
import '../providers/amistad_provider.dart';
import '../../notifications/providers/notificaciones_provider.dart';
import '../../usuarios/screens/usuario_detalle_screen.dart';

/// Igual al breakpoint de `ResponsiveShell` (no se importa de ahí para evitar
/// un ciclo de imports).
const _kEscritorio = 768.0;

class AmistadScreen extends StatefulWidget {
  const AmistadScreen({super.key});

  @override
  State<AmistadScreen> createState() => _AmistadScreenState();
}

class _AmistadScreenState extends State<AmistadScreen> {
  bool _inicializado = false;
  int _tab = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_inicializado) {
      _inicializado = true;
      context.read<AmistadProvider>().cargarTodo();
      context.read<ChatProvider>().cargarConversaciones();
    }
  }

  Widget _buildLista(AmistadProvider prov) {
    if (prov.cargando) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation(SteamColors.blue),
        ),
      );
    }
    return _tab == 0 ? _buildSolicitudes(prov) : _buildAmigos(prov);
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AmistadProvider>();

    final acciones = [
      IconButton(
        icon: const Icon(Icons.refresh, color: SteamColors.blue),
        tooltip: 'Actualizar',
        onPressed: () => prov.cargarTodo(),
      ),
    ];

    final esEscritorio = MediaQuery.of(context).size.width >= _kEscritorio;

    if (esEscritorio) {
      return Scaffold(
        backgroundColor: SteamColors.bgDeep,
        appBar: SteamAppBar(title: 'AMIGOS', actions: acciones),
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 220,
              child: AccesosRapidosPanel(
                children: [
                  const AccesosSeccionTitulo('ACCESOS RÁPIDOS'),
                  AccesoRapidoItem(
                    icon: Icons.people_outline,
                    label: 'Buscar gamers',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const DescubrirGamersScreen()),
                    ),
                  ),
                  const AccesosSeccionTitulo('VER'),
                  AccesoRapidoItem(
                    icon: Icons.inbox_outlined,
                    label: 'Solicitudes (${prov.solicitudes.length})',
                    activo: _tab == 0,
                    onTap: () => setState(() => _tab = 0),
                  ),
                  AccesoRapidoItem(
                    icon: Icons.group_outlined,
                    label: 'Amigos (${prov.amigos.length})',
                    activo: _tab == 1,
                    onTap: () => setState(() => _tab = 1),
                  ),
                ],
              ),
            ),
            const VerticalDivider(color: SteamColors.border, width: 1),
            Expanded(child: _buildLista(prov)),
            const VerticalDivider(color: SteamColors.border, width: 1),
            const SizedBox(width: 260, child: ChatsColumna()),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: SteamColors.bgDeep,
      appBar: SteamAppBar(title: 'AMIGOS', actions: acciones),
      body: DesktopBodyWidth(child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _TabChip(
                  label: 'Solicitudes (${prov.solicitudes.length})',
                  selected: _tab == 0,
                  onTap: () => setState(() => _tab = 0),
                ),
                const SizedBox(width: 10),
                _TabChip(
                  label: 'Amigos (${prov.amigos.length})',
                  selected: _tab == 1,
                  onTap: () => setState(() => _tab = 1),
                ),
              ],
            ),
          ),
          Expanded(child: _buildLista(prov)),
        ],
      )),
    );
  }

  Widget _buildSolicitudes(AmistadProvider prov) {
    if (prov.solicitudes.isEmpty) {
      return const Center(
        child: Text(
          'No tienes solicitudes pendientes.',
          style: TextStyle(color: SteamColors.textSec),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: prov.solicitudes.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final s = prov.solicitudes[index];
        return UsuarioCard(
          usuario: {
            'username_usu': s['solicitante_username'],
            'repu_usu': s['repu_usu'],
          },
          subtitulo: 'Quiere ser tu amigo',
          accion: SizedBox(
            width: 108,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                SteamButtonPrimary(
                  label: 'Aceptar',
                  icon: Icons.check,
                  fullWidth: true,
                  compact: true,
                  onTap: (_) async {
                    await prov.responder(s['id_amistad'], 'Aceptada');
                    if (!context.mounted) return;
                    context.read<NotificacionesProvider>().cargarContador();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Amistad aceptada')),
                    );
                  },
                ),
                const SizedBox(height: 6),
                SteamButtonOutline(
                  label: 'Rechazar',
                  icon: Icons.close,
                  fullWidth: true,
                  compact: true,
                  onTap: () => prov.responder(s['id_amistad'], 'Rechazada'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAmigos(AmistadProvider prov) {
    if (prov.amigos.isEmpty) {
      return const Center(
        child: Text(
          'Aún no tienes amigos agregados.',
          style: TextStyle(color: SteamColors.textSec),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: prov.amigos.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final a = prov.amigos[index];
        final id = a['amigo_id'] as int;
        return UsuarioCard(
          usuario: {
            'username_usu': a['amigo_username'],
            'repu_usu': a['amigo_reputacion'],
          },
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => UsuarioDetalleScreen(userId: id),
              ),
            );
          },
        );
      },
    );
  }
}

class _TabChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TabChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? SteamColors.blue : SteamColors.bgPanel,
            borderRadius: BorderRadius.circular(SteamRadii.sm),
            border: Border.all(color: selected ? SteamColors.blue : SteamColors.border),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.white : SteamColors.light,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
