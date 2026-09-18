// Shell de navegación responsive: en móvil delega tal cual en MainShell
// (bottom nav de 7 pestañas), en escritorio muestra un sidebar izquierdo +
// barra superior (lenguaje visual del wireframe de referencia del usuario:
// sidebar con nav + tus juegos + promo, barra superior con buscador). Mismo
// codebase, mismas pantallas.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/auth/session_actions.dart';
import '../../../l10n/app_localizations.dart';
import '../../../theme/colors.dart';
import '../../../theme/radii.dart';
import '../../amistad/providers/amistad_provider.dart';
import '../../amistad/screens/amistad_screen.dart';
import '../../auth/providers/auth_provider.dart';
import '../../busqueda/screens/busqueda_screen.dart';
import '../../chat/screens/chat_screen.dart';
import '../../chat/widgets/floating_chat.dart';
import '../../descubrir/screens/descubrir_gamers_screen.dart';
import '../../notifications/providers/notificaciones_provider.dart';
import '../../notifications/screens/notifications_screen.dart';
import '../../perfil/providers/perfil_provider.dart';
import '../../perfil/screens/perfil_screen.dart';
import '../../publicaciones/screens/publicaciones_screen.dart';
import 'home_screen.dart';
import 'main_shell.dart';

const kDesktopBreakpoint = 768.0;

class ResponsiveShell extends StatefulWidget {
  const ResponsiveShell({super.key});

  @override
  State<ResponsiveShell> createState() => _ResponsiveShellState();
}

class _ResponsiveShellState extends State<ResponsiveShell> {
  int _index = 0;
  bool _initDone = false;
  String _busquedaDescubrir = '';

  List<Widget> get _pages => [
        HomeScreen(onNavigateIndex: _onSelect),
        DescubrirGamersScreen(busquedaExterna: _busquedaDescubrir),
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
    if (!_initDone && _esEscritorio(context)) {
      _initDone = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<NotificacionesProvider>().cargarContador();
        context.read<AmistadProvider>().cargarTodo();
        final auth = context.read<AuthProvider>();
        final id = auth.usuario?['id'] as int?;
        if (id != null) context.read<PerfilProvider>().cargarPerfil(id);
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

  void _buscarEnDescubrir(String query) {
    setState(() {
      _busquedaDescubrir = query;
      _index = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_esEscritorio(context)) {
      return const MainShell();
    }

    final unreadCount = context.watch<NotificacionesProvider>().noLeidas;
    final solicitudesAmigos = context.watch<AmistadProvider>().solicitudes.length;

    return Scaffold(
      backgroundColor: SteamColors.bgDeep,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SideNav(
            currentIndex: _index,
            badgeAmigos: solicitudesAmigos,
            onSelect: _onSelect,
          ),
          Expanded(
            child: Column(
              children: [
                _TopBar(
                  unreadCount: unreadCount,
                  onBuscar: _buscarEnDescubrir,
                  onNotif: () => _onSelect(6),
                  onPerfil: () => _onSelect(7),
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
          ),
        ],
      ),
    );
  }
}

/// Sidebar izquierdo: logo, navegación principal, atajo a tus juegos y una
/// tarjeta promocional hacia Descubrir. Reemplaza la nav horizontal —
/// estructura pedida explícitamente por el usuario a partir de un wireframe
/// de referencia (ver HANDOFF.md).
class _SideNav extends StatelessWidget {
  final int currentIndex;
  final int badgeAmigos;
  final ValueChanged<int> onSelect;

  const _SideNav({
    required this.currentIndex,
    required this.badgeAmigos,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final juegos = context.watch<PerfilProvider>().juegos;
    final t = AppLocalizations.of(context)!;

    return Container(
      width: 232,
      decoration: const BoxDecoration(
        color: SteamColors.bgPanel,
        border: Border(right: BorderSide(color: SteamColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
            child: InkWell(
              onTap: () => onSelect(0),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
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
          ),
          _SideNavItem(
            icon: Icons.home_outlined,
            activeIcon: Icons.home_rounded,
            label: t.navHome,
            active: currentIndex == 0,
            onTap: () => onSelect(0),
          ),
          _SideNavItem(
            icon: Icons.explore_outlined,
            activeIcon: Icons.explore_rounded,
            label: t.navDiscover,
            active: currentIndex == 1,
            onTap: () => onSelect(1),
          ),
          _SideNavItem(
            icon: Icons.campaign_outlined,
            activeIcon: Icons.campaign_rounded,
            label: t.navPublicaciones,
            active: currentIndex == 2,
            onTap: () => onSelect(2),
          ),
          _SideNavItem(
            icon: Icons.group_outlined,
            activeIcon: Icons.group_rounded,
            label: t.navFriends,
            active: currentIndex == 3,
            badge: badgeAmigos,
            onTap: () => onSelect(3),
          ),
          _SideNavItem(
            icon: Icons.manage_accounts_outlined,
            activeIcon: Icons.manage_accounts_rounded,
            label: t.navProfile,
            active: currentIndex == 7,
            onTap: () => onSelect(7),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
            child: Text(
              t.yourGamesSection,
              style: const TextStyle(
                color: SteamColors.muted,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ),
          if (juegos.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Text(
                t.noGamesYet,
                style: const TextStyle(color: SteamColors.muted, fontSize: 12),
              ),
            )
          else
            for (final j in juegos.take(5)) _MiniJuegoRow(juego: j),
          if (juegos.length > 5)
            Padding(
              padding: const EdgeInsets.only(left: 18, top: 4),
              child: TextButton(
                onPressed: () => onSelect(7),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  alignment: Alignment.centerLeft,
                  minimumSize: const Size(0, 28),
                ),
                child: Text(t.viewAllArrow, style: const TextStyle(fontSize: 12.5)),
              ),
            ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: SteamColors.bgCard,
                borderRadius: BorderRadius.circular(SteamRadii.sm),
                border: Border.all(color: SteamColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.diversity_3, color: SteamColors.blue, size: 20),
                  const SizedBox(height: 8),
                  Text(
                    t.connectPromoTitle,
                    style: const TextStyle(color: SteamColors.light, fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    t.connectPromoBody,
                    style: const TextStyle(color: SteamColors.textSec, fontSize: 11.5, height: 1.4),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => onSelect(1),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: SteamColors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: Text(t.exploreButton, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SideNavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool active;
  final int badge;
  final VoidCallback onTap;

  const _SideNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.active,
    required this.onTap,
    this.badge = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Material(
        color: active ? SteamColors.blue.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(SteamRadii.sm),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(SteamRadii.sm),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              children: [
                Icon(active ? activeIcon : icon, size: 20, color: active ? SteamColors.blue : SteamColors.muted),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: active ? SteamColors.blue : SteamColors.light,
                      fontSize: 13.5,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                if (badge > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: SteamColors.red,
                      borderRadius: BorderRadius.circular(SteamRadii.avatar),
                    ),
                    child: Text(
                      badge > 9 ? '9+' : '$badge',
                      style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700),
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

class _MiniJuegoRow extends StatelessWidget {
  final Map<String, dynamic> juego;

  const _MiniJuegoRow({required this.juego});

  @override
  Widget build(BuildContext context) {
    final header = juego['headerimg'] as String?;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 5),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: SteamColors.bgCard,
              image: header != null && header.isNotEmpty
                  ? DecorationImage(image: NetworkImage(header), fit: BoxFit.cover)
                  : null,
            ),
            child: header == null || header.isEmpty
                ? const Icon(Icons.videogame_asset_outlined, size: 12, color: SteamColors.muted)
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              juego['nombre']?.toString() ?? AppLocalizations.of(context)!.defaultGameName,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: SteamColors.textSec, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}

/// Barra superior: buscador (te lleva a Descubrir con el filtro aplicado),
/// notificaciones y usuario.
class _TopBar extends StatefulWidget {
  final int unreadCount;
  final ValueChanged<String> onBuscar;
  final VoidCallback onNotif;
  final VoidCallback onPerfil;

  const _TopBar({
    required this.unreadCount,
    required this.onBuscar,
    required this.onNotif,
    required this.onPerfil,
  });

  @override
  State<_TopBar> createState() => _TopBarState();
}

class _TopBarState extends State<_TopBar> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: SteamColors.bgPanel,
        border: Border(bottom: BorderSide(color: SteamColors.border, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: TextField(
                controller: _controller,
                textInputAction: TextInputAction.search,
                onSubmitted: widget.onBuscar,
                style: const TextStyle(color: SteamColors.light, fontSize: 13.5),
                decoration: InputDecoration(
                  hintText: 'Buscar jugadores...',
                  hintStyle: const TextStyle(color: SteamColors.muted, fontSize: 13.5),
                  prefixIcon: IconButton(
                    icon: const Icon(Icons.search, color: SteamColors.muted, size: 20),
                    tooltip: 'Buscar',
                    onPressed: () => widget.onBuscar(_controller.text),
                  ),
                  filled: true,
                  fillColor: SteamColors.bgInput,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(SteamRadii.sm),
                    borderSide: const BorderSide(color: SteamColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(SteamRadii.sm),
                    borderSide: const BorderSide(color: SteamColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(SteamRadii.sm),
                    borderSide: const BorderSide(color: SteamColors.blue),
                  ),
                ),
              ),
            ),
          ),
          const Spacer(),
          _NotifBell(unreadCount: widget.unreadCount, onTap: widget.onNotif),
          const SizedBox(width: 8),
          _UserBadge(onTap: widget.onPerfil),
          IconButton(
            icon: const Icon(Icons.logout, size: 18, color: SteamColors.muted),
            tooltip: 'Cerrar sesión',
            onPressed: () => confirmarYCerrarSesion(context),
          ),
        ],
      ),
    );
  }
}

class _NotifBell extends StatelessWidget {
  final int unreadCount;
  final VoidCallback onTap;

  const _NotifBell({required this.unreadCount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined, color: SteamColors.muted),
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
