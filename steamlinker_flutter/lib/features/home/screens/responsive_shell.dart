// Shell de navegación responsive: en móvil delega tal cual en MainShell
// (bottom nav de 3 pestañas), en escritorio muestra un sidebar persistente
// con todos los destinos, sin bottom nav. Mismo codebase, mismas pantallas.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/auth/session_actions.dart';
import '../../../theme/colors.dart';
import '../../../theme/radii.dart';
import '../../amistad/screens/amistad_screen.dart';
import '../../auth/providers/auth_provider.dart';
import '../../busqueda/screens/busqueda_screen.dart';
import '../../chat/screens/chat_screen.dart';
import '../../descubrir/screens/descubrir_gamers_screen.dart';
import '../../notifications/providers/notificaciones_provider.dart';
import '../../notifications/screens/notifications_screen.dart';
import '../../perfil/screens/perfil_screen.dart';
import '../../publicaciones/screens/publicaciones_screen.dart';
import 'home_screen.dart';
import 'main_shell.dart';

/// Por debajo de este ancho se usa el shell móvil (MainShell) tal cual.
const kDesktopBreakpoint = 768.0;

class ResponsiveShell extends StatefulWidget {
  const ResponsiveShell({super.key});

  @override
  State<ResponsiveShell> createState() => _ResponsiveShellState();
}

class _NavEntry {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  const _NavEntry(this.label, this.icon, this.activeIcon);
}

class _ResponsiveShellState extends State<ResponsiveShell> {
  int _index = 0;
  bool _notifInit = false;

  static const _items = [
    _NavEntry('Inicio', Icons.home_outlined, Icons.home_rounded),
    _NavEntry('Descubrir', Icons.people_outline, Icons.people_rounded),
    _NavEntry('Publicaciones', Icons.campaign_outlined, Icons.campaign_rounded),
    _NavEntry('Amigos', Icons.group_outlined, Icons.group_rounded),
    _NavEntry('Buscar juegos', Icons.search_rounded, Icons.search_rounded),
    _NavEntry('Mensajes', Icons.chat_bubble_outline, Icons.chat_bubble_rounded),
    _NavEntry('Notificaciones', Icons.notifications_outlined, Icons.notifications_rounded),
    _NavEntry('Perfil', Icons.person_outline, Icons.person_rounded),
  ];

  // No es const: HomeScreen recibe el callback para que sus tarjetas de
  // acceso rápido cambien de sección del sidebar en vez de empujar una
  // pantalla nueva por encima (ver home_screen.dart).
  List<Widget> get _pages => [
        HomeScreen(onNavigateIndex: _onSelect),
        const DescubrirGamersScreen(),
        const PublicacionesScreen(),
        const AmistadScreen(),
        const BusquedaScreen(),
        const ChatScreen(),
        const NotificationsScreen(),
        const PerfilScreen(),
      ];

  bool _esEscritorio(BuildContext context) =>
      MediaQuery.of(context).size.width >= kDesktopBreakpoint;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // El init de notificaciones de MainShell cubre el caso móvil; aquí solo
    // hace falta cuando de verdad vamos a mostrar el sidebar de escritorio.
    if (!_notifInit && _esEscritorio(context)) {
      _notifInit = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<NotificacionesProvider>().cargarContador();
      });
    }
  }

  void _onSelect(int i) {
    setState(() => _index = i);
    if (i == 6) {
      context.read<NotificacionesProvider>().cargar();
    } else {
      context.read<NotificacionesProvider>().cargarContador();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_esEscritorio(context)) {
      return const MainShell();
    }

    final unreadCount = context.watch<NotificacionesProvider>().noLeidas;

    return Scaffold(
      backgroundColor: SteamColors.bgDeep,
      body: Row(
        children: [
          _Sidebar(
            items: _items,
            currentIndex: _index,
            unreadCount: unreadCount,
            onSelect: _onSelect,
          ),
          Expanded(child: IndexedStack(index: _index, children: _pages)),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  final List<_NavEntry> items;
  final int currentIndex;
  final int unreadCount;
  final ValueChanged<int> onSelect;

  const _Sidebar({
    required this.items,
    required this.currentIndex,
    required this.unreadCount,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 232,
      decoration: const BoxDecoration(
        color: SteamColors.bgPanel,
        border: Border(right: BorderSide(color: SteamColors.border, width: 1)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: SteamColors.blue,
                    borderRadius: BorderRadius.circular(SteamRadii.sm),
                  ),
                  child: const Icon(Icons.sports_esports, size: 16, color: SteamColors.bgDeep),
                ),
                const SizedBox(width: 10),
                const Text(
                  'SteamMatch',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const Divider(color: SteamColors.border, height: 1),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              itemCount: items.length,
              itemBuilder: (context, i) {
                final activo = i == currentIndex;
                final badge = i == 6 ? unreadCount : 0;
                return _SidebarItem(
                  entry: items[i],
                  activo: activo,
                  badge: badge,
                  onTap: () => onSelect(i),
                );
              },
            ),
          ),
          const Divider(color: SteamColors.border, height: 1),
          _UserFooter(),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final _NavEntry entry;
  final bool activo;
  final int badge;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.entry,
    required this.activo,
    required this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: activo ? SteamColors.bgCard : Colors.transparent,
        borderRadius: BorderRadius.circular(SteamRadii.sm),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(SteamRadii.sm),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 16,
                  decoration: BoxDecoration(
                    color: activo ? SteamColors.blue : Colors.transparent,
                    borderRadius: BorderRadius.circular(SteamRadii.sm),
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  activo ? entry.activeIcon : entry.icon,
                  size: 19,
                  color: activo ? SteamColors.blue : SteamColors.muted,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    entry.label,
                    style: TextStyle(
                      color: activo ? SteamColors.light : SteamColors.textSec,
                      fontSize: 13.5,
                      fontWeight: activo ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
                if (badge > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: SteamColors.red,
                      borderRadius: BorderRadius.circular(SteamRadii.sm),
                    ),
                    child: Text(
                      badge > 9 ? '9+' : '$badge',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UserFooter extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        final username = auth.usuario?['username'] ?? 'Usuario';
        final inicial = username.isNotEmpty ? username[0].toUpperCase() : 'U';

        return Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(SteamRadii.sm),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2A4A6B), SteamColors.teal],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(color: SteamColors.blue, width: 1.5),
                ),
                child: Center(
                  child: Text(
                    inicial,
                    style: const TextStyle(color: SteamColors.light, fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  username,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: SteamColors.light, fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.logout, size: 18, color: SteamColors.muted),
                tooltip: 'Cerrar sesión',
                onPressed: () => confirmarYCerrarSesion(context),
              ),
            ],
          ),
        );
      },
    );
  }
}
