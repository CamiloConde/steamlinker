// Shell de navegación responsive: en móvil delega tal cual en MainShell
// (bottom nav de 3 pestañas), en escritorio muestra una barra de navegación
// superior persistente (lenguaje visual del wireframe: nav horizontal, no
// sidebar), sin bottom nav. Mismo codebase, mismas pantallas.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/auth/session_actions.dart';
import '../../../theme/colors.dart';
import '../../../theme/radii.dart';
import '../../amistad/screens/amistad_screen.dart';
import '../../auth/providers/auth_provider.dart';
import '../../busqueda/screens/busqueda_screen.dart';
import '../../chat/screens/chat_screen.dart';
import '../../chat/widgets/floating_chat.dart';
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

class _ResponsiveShellState extends State<ResponsiveShell> {
  int _index = 0;
  bool _notifInit = false;

  // No es const: HomeScreen recibe el callback para que sus tarjetas de
  // acceso rápido cambien de sección en vez de empujar una pantalla nueva
  // por encima (ver home_screen.dart).
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
    // hace falta cuando de verdad vamos a mostrar la nav de escritorio.
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
      body: Column(
        children: [
          _TopNav(
            currentIndex: _index,
            unreadCount: unreadCount,
            onSelect: _onSelect,
          ),
          Expanded(
            child: Stack(
              children: [
                IndexedStack(index: _index, children: _pages),
                const Positioned(right: 20, bottom: 20, child: FloatingChat()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Barra de navegación horizontal (lenguaje visual del wireframe): logo a la
/// izquierda (vuelve a Inicio), pestañas principales al centro con subrayado
/// azul en la activa, y a la derecha accesos rápidos + usuario.
class _TopNav extends StatelessWidget {
  final int currentIndex;
  final int unreadCount;
  final ValueChanged<int> onSelect;

  const _TopNav({
    required this.currentIndex,
    required this.unreadCount,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      decoration: const BoxDecoration(
        color: SteamColors.bgPanel,
        border: Border(bottom: BorderSide(color: SteamColors.border, width: 1)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 24),
          InkWell(
            onTap: () => onSelect(0),
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
          const SizedBox(width: 36),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _NavTab(label: 'Perfil', active: currentIndex == 7, onTap: () => onSelect(7)),
                _NavTab(label: 'Descubrir', active: currentIndex == 1, onTap: () => onSelect(1)),
                _NavTab(label: 'Publicaciones', active: currentIndex == 2, onTap: () => onSelect(2)),
                _NavTab(label: 'Amigos', active: currentIndex == 3, onTap: () => onSelect(3)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.search_rounded, color: SteamColors.muted),
            tooltip: 'Buscar juegos',
            onPressed: () => onSelect(4),
          ),
          _NotifBell(
            unreadCount: unreadCount,
            active: currentIndex == 6,
            onTap: () => onSelect(6),
          ),
          const SizedBox(width: 8),
          _UserBadge(onTap: () => onSelect(7)),
          IconButton(
            icon: const Icon(Icons.logout, size: 18, color: SteamColors.muted),
            tooltip: 'Cerrar sesión',
            onPressed: () => confirmarYCerrarSesion(context),
          ),
          const SizedBox(width: 16),
        ],
      ),
    );
  }
}

class _NavTab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _NavTab({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 14),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active ? SteamColors.blue : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? SteamColors.blue : SteamColors.light,
            fontSize: 14.5,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _NotifBell extends StatelessWidget {
  final int unreadCount;
  final bool active;
  final VoidCallback onTap;

  const _NotifBell({required this.unreadCount, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: Icon(
            active ? Icons.notifications_rounded : Icons.notifications_outlined,
            color: active ? SteamColors.blue : SteamColors.muted,
          ),
          tooltip: 'Notificaciones',
          onPressed: onTap,
        ),
        if (unreadCount > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: SteamColors.red,
                borderRadius: BorderRadius.circular(SteamRadii.avatar),
              ),
              child: Text(
                unreadCount > 9 ? '9+' : '$unreadCount',
                style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
              ),
            ),
          ),
      ],
    );
  }
}

class _UserBadge extends StatelessWidget {
  final VoidCallback onTap;

  const _UserBadge({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        final username = auth.usuario?['username'] ?? 'Usuario';
        final inicial = username.isNotEmpty ? username[0].toUpperCase() : 'U';

        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(SteamRadii.sm),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(SteamRadii.avatar),
                    gradient: const LinearGradient(
                      colors: [SteamColors.blue, SteamColors.teal],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(color: SteamColors.blue, width: 1.5),
                  ),
                  child: Center(
                    child: Text(
                      inicial,
                      style: const TextStyle(color: SteamColors.light, fontSize: 11, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 110),
                  child: Text(
                    username,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: SteamColors.light, fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
