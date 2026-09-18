import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/notification_model.dart';
import '../../../theme/colors.dart';
import '../../../theme/radii.dart';
import '../../../widgets/desktop_body_width.dart';
import '../../../widgets/notification_tile.dart';
import '../../../widgets/steam_app_bar.dart';
import '../../../core/navigation/app_navigator.dart';
import '../../amistad/screens/amistad_screen.dart';
import '../../chat/screens/chat_conversation_screen.dart';
import '../../matches/screens/matches_screen.dart';
import '../providers/notificaciones_provider.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _filters = ['Todas', 'No leídas', 'Marcadas'];
  bool _inicializado = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _filters.length, vsync: this);
    _tabs.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (!_tabs.indexIsChanging && _inicializado) {
      _cargarFiltroActual();
    }
  }

  String? _filtroApi() {
    switch (_tabs.index) {
      case 1:
        return 'no_leidas';
      case 2:
        return 'interesantes';
      default:
        return null;
    }
  }

  Future<void> _cargarFiltroActual() async {
    await context.read<NotificacionesProvider>().cargar(filtro: _filtroApi());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_inicializado) {
      _inicializado = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _cargarFiltroActual();
      });
    }
  }

  @override
  void dispose() {
    _tabs.removeListener(_onTabChanged);
    _tabs.dispose();
    super.dispose();
  }

  void _navegarDesdeNotif(NotificationModel n) {
    switch (n.refTipo) {
      case 'match':
        pushAppScreen(context, const MatchesScreen());
        break;
      case 'amistad':
        pushAppScreen(context, const AmistadScreen());
        break;
      case 'chat':
        if (n.refId != null) {
          final nombre = n.title.replaceFirst(
            RegExp(r'^Nuevo mensaje de\s*', caseSensitive: false),
            '',
          );
          pushAppScreen(
            context,
            ChatConversationScreen(
              chatId: n.refId!,
              otroNombre: nombre.isNotEmpty ? nombre : 'Chat',
            ),
          );
        }
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<NotificacionesProvider>();
    final unread = prov.noLeidas;
    final marcadas = prov.notificaciones.where((n) => n.interested == true).length;
    // Las marcadas se anclan arriba en "Todas"/"No leídas": para eso sirve
    // marcar algo — encontrarlo sin desplazarse por el resto de la lista.
    // En la pestaña "Marcadas" ya vienen filtradas por el backend, así que
    // el orden original (más reciente primero) es el correcto.
    final lista = _tabs.index == 2
        ? prov.notificaciones
        : [
            ...prov.notificaciones.where((n) => n.interested == true),
            ...prov.notificaciones.where((n) => n.interested != true),
          ];

    return Scaffold(
      backgroundColor: SteamColors.bgDeep,
      appBar: SteamAppBar(
        title: 'NOTIFICACIONES',
        showBack: false,
        // En escritorio la nav superior global ya muestra el usuario.
        showUserActions: MediaQuery.of(context).size.width < 768,
        actions: [
          if (unread > 0)
            TextButton(
              onPressed: () async {
                await prov.marcarTodasLeidas();
              },
              child: const Text(
                'Todo leído',
                style: TextStyle(
                  color: SteamColors.blue,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh, color: SteamColors.blue),
            tooltip: 'Actualizar',
            onPressed: _cargarFiltroActual,
          ),
        ],
      ),
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
              tabs: [
                _buildTab('Todas', 0),
                _buildTab('No leídas', unread, badgeColor: SteamColors.red),
                _buildTab('Marcadas', marcadas, badgeColor: SteamColors.yellow),
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
                : prov.error != null
                    ? Center(
                        child: Text(
                          prov.error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      )
                    : lista.isEmpty
                        ? _EmptyState(filter: _filters[_tabs.index])
                        : RefreshIndicator(
                            color: SteamColors.blue,
                            onRefresh: _cargarFiltroActual,
                            child: ListView.separated(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemCount: lista.length,
                              separatorBuilder: (_, _) => const Divider(
                                color: SteamColors.border,
                                height: 1,
                                indent: 16,
                                endIndent: 16,
                              ),
                              itemBuilder: (ctx, i) {
                                final n = lista[i];
                                return NotificationTile(
                                  notif: n,
                                  onOpen: () => _navegarDesdeNotif(n),
                                  onChanged: () => setState(() {}),
                                  onToggleRead: (leida) =>
                                      prov.marcarLeida(n.id, leida),
                                  onInteres: (interes) =>
                                      prov.marcarInteres(n.id, interes),
                                );
                              },
                            ),
                          ),
          ),
        ],
      )),
    );
  }

  Tab _buildTab(String label, int count, {Color badgeColor = SteamColors.blue}) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (count > 0) ...[
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: badgeColor,
                borderRadius: BorderRadius.circular(SteamRadii.sm),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String filter;

  const _EmptyState({required this.filter});

  @override
  Widget build(BuildContext context) {
    final esMarcadas = filter == 'Marcadas';
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              esMarcadas
                  ? Icons.bookmark_border_rounded
                  : Icons.notifications_off_outlined,
              size: 56,
              color: SteamColors.muted.withValues(alpha: 0.35),
            ),
            const SizedBox(height: 16),
            Text(
              esMarcadas ? 'Sin notificaciones marcadas' : 'Todo al día',
              style: const TextStyle(
                color: SteamColors.light,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              esMarcadas
                  ? 'Toca el menú de tres puntos de una notificación para marcarla: '
                      'quedará fijada arriba en Todas y No leídas hasta que la desmarques.'
                  : 'Te avisaremos de mensajes, matches y solicitudes de amistad',
              style: const TextStyle(color: SteamColors.textSec, fontSize: 12.5),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
