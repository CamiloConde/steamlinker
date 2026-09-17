import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../theme/colors.dart';
import '../../../theme/radii.dart';
import '../../amistad/screens/amistad_screen.dart';
import '../../chat/screens/chat_screen.dart';
import '../../descubrir/screens/descubrir_gamers_screen.dart';
import '../../notifications/providers/notificaciones_provider.dart';
import '../../publicaciones/screens/publicaciones_screen.dart';
import '../screens/home_screen.dart';
import '../../notifications/screens/notifications_screen.dart';
import '../../perfil/screens/perfil_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  bool _notifInit = false;

  // Inicio dejó de tener tarjetas de acceso rápido a Descubrir/Publicaciones/
  // Amigos/Mensajes (rediseño "bandeja de pendientes", ver HANDOFF.md) — en
  // escritorio esas pantallas ya viven en la nav superior o el chat
  // flotante, pero en móvil no hay otra nav, así que el bottom nav es su
  // único punto de entrada real.
  final List<Widget> _pages = const [
    HomeScreen(),
    DescubrirGamersScreen(),
    PublicacionesScreen(),
    AmistadScreen(),
    ChatScreen(),
    NotificationsScreen(),
    PerfilScreen(),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_notifInit) {
      _notifInit = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<NotificacionesProvider>().cargarContador();
      });
    }
  }

  void _onNavTap(int index) {
    setState(() => _currentIndex = index);
    if (index == 5) {
      context.read<NotificacionesProvider>().cargar();
    } else {
      context.read<NotificacionesProvider>().cargarContador();
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = context.watch<NotificacionesProvider>().noLeidas;

    return Scaffold(
      backgroundColor: SteamColors.bgDeep,
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: _BottomNavBar(
        currentIndex: _currentIndex,
        unreadCount: unreadCount,
        onTap: _onNavTap,
      ),
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final int unreadCount;
  final ValueChanged<int> onTap;

  const _BottomNavBar({
    required this.currentIndex,
    required this.unreadCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: SteamColors.bgPanel,
        border: Border(top: BorderSide(color: SteamColors.border, width: 1)),
      ),
      child: SafeArea(
        child: SizedBox(
          height: 60,
          child: Row(children: [
            _NavItem(
              icon: Icons.home_outlined,
              activeIcon: Icons.home_rounded,
              label: 'Inicio',
              index: 0,
              currentIndex: currentIndex,
              onTap: () => onTap(0),
            ),
            _NavItem(
              icon: Icons.people_outline,
              activeIcon: Icons.people_rounded,
              label: 'Descubrir',
              index: 1,
              currentIndex: currentIndex,
              onTap: () => onTap(1),
            ),
            _NavItem(
              icon: Icons.campaign_outlined,
              activeIcon: Icons.campaign_rounded,
              label: 'Publica.',
              index: 2,
              currentIndex: currentIndex,
              onTap: () => onTap(2),
            ),
            _NavItem(
              icon: Icons.group_outlined,
              activeIcon: Icons.group_rounded,
              label: 'Amigos',
              index: 3,
              currentIndex: currentIndex,
              onTap: () => onTap(3),
            ),
            _NavItem(
              icon: Icons.chat_bubble_outline,
              activeIcon: Icons.chat_bubble_rounded,
              label: 'Chat',
              index: 4,
              currentIndex: currentIndex,
              onTap: () => onTap(4),
            ),
            _NavItem(
              icon: Icons.notifications_outlined,
              activeIcon: Icons.notifications_rounded,
              label: 'Avisos',
              index: 5,
              currentIndex: currentIndex,
              badge: unreadCount,
              onTap: () => onTap(5),
            ),
            _NavItem(
              icon: Icons.manage_accounts_outlined,
              activeIcon: Icons.manage_accounts_rounded,
              label: 'Perfil',
              index: 6,
              currentIndex: currentIndex,
              onTap: () => onTap(6),
            ),
          ]),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int index;
  final int currentIndex;
  final int badge;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.index,
    required this.currentIndex,
    required this.onTap,
    this.badge = 0,
  });

  bool get _active => index == currentIndex;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(clipBehavior: Clip.none, children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: Icon(
                  _active ? activeIcon : icon,
                  key: ValueKey(_active),
                  color: _active ? SteamColors.blue : SteamColors.muted,
                  size: 21,
                ),
              ),
              if (badge > 0)
                Positioned(
                  top: -5,
                  right: -7,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: SteamColors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      badge > 9 ? '9+' : '$badge',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ]),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 180),
              style: TextStyle(
                color: _active ? SteamColors.blue : SteamColors.muted,
                fontSize: 9,
                fontWeight: _active ? FontWeight.w700 : FontWeight.w400,
                letterSpacing: 0.2,
              ),
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(height: 2),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 2,
              width: _active ? 24 : 0,
              decoration: BoxDecoration(
                color: SteamColors.blue,
                borderRadius: BorderRadius.circular(SteamRadii.sm),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
