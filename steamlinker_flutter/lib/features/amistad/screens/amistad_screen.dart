import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/refresh_signal.dart';
import '../../../theme/colors.dart';
import '../../../theme/radii.dart';
import '../../../widgets/desktop_body_width.dart';
import '../../../widgets/steam_app_bar.dart';
import '../../../widgets/steam_buttons.dart';
import '../../../widgets/steam_toast.dart';
import '../../../widgets/usuario_card.dart';
import '../providers/amistad_provider.dart';
import '../../notifications/providers/notificaciones_provider.dart';
import '../../usuarios/screens/usuario_detalle_screen.dart';

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
    }
  }

  @override
  void initState() {
    super.initState();
    refreshSignal.addListener(_onRefreshSignal);
  }

  @override
  void dispose() {
    refreshSignal.removeListener(_onRefreshSignal);
    super.dispose();
  }

  void _onRefreshSignal() {
    if (refreshSignal.indice == 3) context.read<AmistadProvider>().cargarTodo();
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AmistadProvider>();
    final esEscritorio = MediaQuery.of(context).size.width >= 768;

    // Si esta pantalla se llegó pusheándola encima (no como pestaña del
    // IndexedStack de ResponsiveShell -- ej. desde un enlace en Avisos),
    // sí hace falta la barra con flecha de volver aunque sea escritorio,
    // porque ahí no hay forma de volver. Bug real encontrado por el
    // usuario: "Ver todos" desde una publicación abierta en Inicio lo
    // dejaba sin poder volver. Ver HANDOFF.md.
    final puedeVolver = Navigator.of(context, rootNavigator: true).canPop();

    return Scaffold(
      backgroundColor: SteamColors.bgDeep,
      // En escritorio la barra global de ResponsiveShell ya trae un botón
      // de refrescar único (ver _TopBar) -- repetirlo aquí en una barra
      // propia sin título (por el "fundirConFondo" de SteamAppBar) dejaba
      // un solo ícono flotando en ~57px vacíos. Se elimina del todo acá
      // solo cuando esta pantalla es una pestaña de verdad (no se puede
      // volver); en móvil (sin barra global) sigue haciendo falta.
      appBar: (esEscritorio && !puedeVolver)
          ? null
          : SteamAppBar(
              title: 'AMIGOS',
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh, color: SteamColors.blue),
                  tooltip: 'Actualizar',
                  onPressed: () => prov.cargarTodo(),
                ),
              ],
            ),
      body: DesktopBodyWidth(
        child: Column(
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
            Expanded(
              child: prov.cargando
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation(SteamColors.blue),
                      ),
                    )
                  : _tab == 0
                  ? _buildSolicitudes(prov)
                  : _buildAmigos(prov),
            ),
          ],
        ),
      ),
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
                    showSteamToast(
                      context,
                      'Amistad aceptada',
                      SteamColors.green,
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
      child: Material(
        color: selected ? SteamColors.blue : SteamColors.bgPanel,
        borderRadius: BorderRadius.circular(SteamRadii.sm),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(SteamRadii.sm),
          hoverColor: (selected ? Colors.white : SteamColors.blue).withValues(
            alpha: 0.08,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(SteamRadii.sm),
              border: Border.all(
                color: selected ? SteamColors.blue : SteamColors.border,
              ),
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
      ),
    );
  }
}
