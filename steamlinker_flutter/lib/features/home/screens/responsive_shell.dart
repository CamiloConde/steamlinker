// Shell de navegación responsive: en móvil delega tal cual en MainShell
// (bottom nav de 7 pestañas), en escritorio muestra un sidebar izquierdo +
// barra superior (lenguaje visual del wireframe de referencia del usuario:
// sidebar con nav + tus juegos + promo, barra superior con buscador). Mismo
// codebase, mismas pantallas.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/auth/session_actions.dart';
import '../../../l10n/app_localizations.dart';
import '../../../theme/colors.dart';
import '../../../theme/radii.dart';
import '../../../widgets/app_logo_mark.dart';
import '../../../widgets/avatar_foto.dart';
import '../../../widgets/steam_toast.dart';
import '../../amistad/providers/amistad_provider.dart';
import '../../amistad/screens/amistad_screen.dart';
import '../../auth/providers/auth_provider.dart';
import '../../busqueda/screens/busqueda_screen.dart';
import '../../chat/screens/chat_screen.dart';
import '../../chat/widgets/floating_chat.dart';
import '../../descubrir/screens/descubrir_gamers_screen.dart';
import '../../notifications/providers/notificaciones_provider.dart';
import '../../notifications/screens/notifications_screen.dart';
import '../../perfil/perfil_scroll_signal.dart';
import '../../perfil/providers/perfil_provider.dart';
import '../../perfil/screens/apoyar_proyecto_screen.dart';
import '../../perfil/screens/perfil_screen.dart';
import '../../publicaciones/screens/publicaciones_screen.dart';
import '../../../core/refresh_signal.dart';
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
  bool _steamCallbackChecked = false;
  String _busquedaDescubrir = '';
  int? _filtroAppidDescubrir;
  String? _filtroJuegoNombreDescubrir;

  List<Widget> get _pages => [
    HomeScreen(onNavigateIndex: _onSelect),
    DescubrirGamersScreen(
      busquedaExterna: _busquedaDescubrir,
      filtroAppidExterno: _filtroAppidDescubrir,
      filtroJuegoNombreExterno: _filtroJuegoNombreDescubrir,
      esPestana: true,
    ),
    const PublicacionesScreen(esPestana: true),
    const AmistadScreen(esPestana: true),
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
    if (!_steamCallbackChecked) {
      _steamCallbackChecked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _procesarResultadoSteam();
      });
    }
  }

  /// Al volver del login con Steam (OpenID), el backend redirige acá con
  /// ?steam=ok o ?steam=error&motivo=... en la URL. Se muestra el
  /// resultado, se refresca el perfil si vinculó, y se limpia la URL para
  /// no repetir el aviso si la página se recarga a mano.
  void _procesarResultadoSteam() {
    final params = GoRouterState.of(context).uri.queryParameters;
    final steam = params['steam'];
    if (steam == null) return;

    if (steam == 'ok') {
      final bibliotecaImportada = params['biblioteca'] == 'importada';
      showSteamToast(
        context,
        bibliotecaImportada
            ? 'Cuenta de Steam vinculada y biblioteca importada'
            : 'Cuenta de Steam vinculada. Tu perfil de Steam debe ser público '
                  'para importar la biblioteca automáticamente — hazlo a mano desde Perfil.',
        SteamColors.green,
      );
      final auth = context.read<AuthProvider>();
      final id = auth.usuario?['id'] as int?;
      if (id != null) context.read<PerfilProvider>().cargarPerfil(id);
    } else if (steam == 'error') {
      const mensajes = {
        'sesion_expirada': 'El enlace de Steam expiró. Inténtalo de nuevo.',
        'cancelado': 'Inicio de sesión con Steam cancelado.',
        'proveedor_invalido':
            'Respuesta inesperada de Steam. Inténtalo de nuevo.',
        'firma_invalida':
            'No se pudo verificar tu sesión de Steam. Inténtalo de nuevo.',
        'id_invalido': 'No se pudo identificar tu cuenta de Steam.',
        'error_servidor': 'Ocurrió un error al vincular tu cuenta de Steam.',
      };
      final motivo = params['motivo'];
      showSteamToast(
        context,
        mensajes[motivo] ?? 'No se pudo vincular tu cuenta de Steam.',
        SteamColors.red,
      );
    }

    context.go('/home');
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

  void _filtrarDescubrirPorJuego(int appid, String nombre) {
    setState(() {
      _filtroAppidDescubrir = appid;
      _filtroJuegoNombreDescubrir = nombre;
      _index = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_esEscritorio(context)) {
      return const MainShell();
    }

    final unreadCount = context.watch<NotificacionesProvider>().noLeidas;
    final solicitudesAmigos = context
        .watch<AmistadProvider>()
        .solicitudes
        .length;

    return Scaffold(
      backgroundColor: SteamColors.bgDeep,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SideNav(
            currentIndex: _index,
            badgeAmigos: solicitudesAmigos,
            onSelect: _onSelect,
            onJuegoTap: _filtrarDescubrirPorJuego,
          ),
          Expanded(
            child: Column(
              children: [
                _TopBar(
                  unreadCount: unreadCount,
                  onBuscar: _buscarEnDescubrir,
                  onNotif: () => _onSelect(6),
                  onPerfil: () => _onSelect(7),
                  onRefrescar: () => refreshSignal.pedirRefresh(_index),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      IndexedStack(index: _index, children: _pages),
                      const Positioned(
                        right: 20,
                        bottom: 20,
                        child: FloatingChat(),
                      ),
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
  final void Function(int appid, String nombre) onJuegoTap;

  const _SideNav({
    required this.currentIndex,
    required this.badgeAmigos,
    required this.onSelect,
    required this.onJuegoTap,
  });

  @override
  Widget build(BuildContext context) {
    // Antes mostraba siempre los primeros 5 de la biblioteca sin que el
    // usuario pudiera elegir cuáles -- pedido explícito: reutiliza el
    // sistema de favoritos que ya existe en Perfil (la estrella en cada
    // juego) en vez de agregar un selector nuevo. Los marcados como
    // favoritos aparecen primero; si no hay ninguno, el orden no cambia.
    // Partición manual (no List.sort) para que el orden dentro de cada
    // grupo se mantenga estable -- List.sort no lo garantiza.
    final todos = context.watch<PerfilProvider>().juegos;
    final hayFavoritos = todos.any((j) => j['favorito'] == true);
    final juegos = [
      ...todos.where((j) => j['favorito'] == true),
      ...todos.where((j) => j['favorito'] != true),
    ];
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
                    child: const AppLogoMark(
                      size: 16,
                      color: SteamColors.bgDeep,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'SteamMatch',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
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
          else ...[
            // Pedido explícito del usuario: no era obvio por qué salían
            // justo esos 5 -- se aclara acá, pero solo si de verdad hay
            // algún favorito marcado (si no, el orden es el de siempre
            // y esta aclaración no aplicaría a nada).
            if (hayFavoritos)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 6),
                child: Text(
                  'Se muestran primero tus favoritos ⭐',
                  style: TextStyle(
                    color: SteamColors.muted.withValues(alpha: 0.8),
                    fontSize: 10.5,
                  ),
                ),
              ),
            for (final j in juegos.take(5))
              _MiniJuegoRow(
                juego: j,
                onTap: () {
                  final appid = j['appid'] as int?;
                  if (appid == null) return;
                  onJuegoTap(appid, j['nombre']?.toString() ?? '');
                },
              ),
          ],
          if (juegos.length > 5)
            Padding(
              padding: const EdgeInsets.only(left: 18, top: 4),
              child: TextButton(
                onPressed: () {
                  onSelect(7);
                  // Perfil ya está montado dentro del IndexedStack (no se
                  // reconstruye al cambiar de pestaña), así que el
                  // listener alcanza a desplazarse aunque ya estuviera
                  // visible antes de este clic.
                  perfilScrollSignal.pedirScrollAJuegos();
                },
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  alignment: Alignment.centerLeft,
                  minimumSize: const Size(0, 28),
                ),
                child: Text(
                  t.viewAllArrow,
                  style: const TextStyle(fontSize: 12.5),
                ),
              ),
            ),
          const Spacer(),
          // Antes había una tarjeta "Conecta con otros gamers" acá cuyo
          // único botón llevaba a Descubrir -- exactamente el mismo
          // destino que el ítem de nav "Descubrir" un poco más arriba en
          // este mismo sidebar. Se reemplaza por "Apoya el proyecto"
          // (antes solo visible al fondo del scroll de Inicio): acá queda
          // visible en todas las pantallas de escritorio sin scrollear.
          // Versión compacta propia (no SteamCard, pensado para un
          // contenido ancho) para que quepa bien en los 232px del rail.
          const Padding(
            padding: EdgeInsets.fromLTRB(18, 0, 18, 18),
            child: _ApoyarProyectoSidebar(),
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
        color: active
            ? SteamColors.blue.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(SteamRadii.sm),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(SteamRadii.sm),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              children: [
                Icon(
                  active ? activeIcon : icon,
                  size: 20,
                  color: active ? SteamColors.blue : SteamColors.muted,
                ),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: SteamColors.red,
                      borderRadius: BorderRadius.circular(SteamRadii.avatar),
                    ),
                    child: Text(
                      badge > 9 ? '9+' : '$badge',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
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

/// Versión compacta de ApoyarProyectoCard para el rail lateral (232px):
/// la tarjeta original usa SteamCard, pensada para el ancho de una
/// pantalla completa -- su encabezado ("APOYA EL PROYECTO" en mayúsculas)
/// no entra cómodo en un espacio tan angosto. Misma lógica de apertura
/// del enlace, chrome más simple.
class _ApoyarProyectoSidebar extends StatelessWidget {
  const _ApoyarProyectoSidebar();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SteamColors.bgCard,
        borderRadius: BorderRadius.circular(SteamRadii.sm),
        border: Border.all(color: SteamColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.favorite_border_rounded,
            color: SteamColors.yellow,
            size: 20,
          ),
          const SizedBox(height: 8),
          const Text(
            'Apoya el proyecto',
            style: TextStyle(
              color: SteamColors.light,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'SteamMatch es gratis e independiente. Ayúdanos a seguir '
            'mejorándolo.',
            style: TextStyle(
              color: SteamColors.textSec,
              fontSize: 11.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              // Ya no abre Ko-fi directo -- lleva a ApoyarProyectoScreen,
              // que separa Colombia (llave Bre-B) de otros países (Ko-fi).
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ApoyarProyectoScreen()),
              ),
              icon: const Icon(Icons.favorite_rounded, size: 16),
              label: const Text(
                'Ver cómo apoyar',
                style: TextStyle(fontSize: 12.5),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: SteamColors.yellow,
                foregroundColor: SteamColors.bgDeep,
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Antes solo mostraba el juego como texto suelto, sin ninguna acción —
/// ahora un clic lleva directo a Descubrir ya filtrado por ese juego (en
/// vez de ser una lista puramente decorativa, ver HANDOFF.md).
class _MiniJuegoRow extends StatelessWidget {
  final Map<String, dynamic> juego;
  final VoidCallback onTap;

  const _MiniJuegoRow({required this.juego, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final header = juego['headerimg'] as String?;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 5),
          child: Row(
            children: [
              Semantics(
                image: true,
                label: 'Carátula de ${juego['nombre'] ?? 'juego'}',
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: SteamColors.bgCard,
                    image: header != null && header.isNotEmpty
                        ? DecorationImage(
                            image: NetworkImage(header),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: header == null || header.isEmpty
                      ? const Icon(
                          Icons.videogame_asset_outlined,
                          size: 12,
                          color: SteamColors.muted,
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  juego['nombre']?.toString() ??
                      AppLocalizations.of(context)!.defaultGameName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: SteamColors.textSec,
                    fontSize: 12.5,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: 14,
                color: SteamColors.muted,
              ),
            ],
          ),
        ),
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
  final VoidCallback onRefrescar;

  const _TopBar({
    required this.unreadCount,
    required this.onBuscar,
    required this.onNotif,
    required this.onPerfil,
    required this.onRefrescar,
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
                style: const TextStyle(
                  color: SteamColors.light,
                  fontSize: 13.5,
                ),
                decoration: InputDecoration(
                  hintText: 'Buscar jugadores...',
                  hintStyle: const TextStyle(
                    color: SteamColors.muted,
                    fontSize: 13.5,
                  ),
                  prefixIcon: IconButton(
                    icon: const Icon(
                      Icons.search,
                      color: SteamColors.muted,
                      size: 20,
                    ),
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
          IconButton(
            icon: const Icon(Icons.refresh, color: SteamColors.muted),
            tooltip: 'Actualizar',
            onPressed: widget.onRefrescar,
          ),
          const SizedBox(width: 4),
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
          icon: const Icon(
            Icons.notifications_outlined,
            color: SteamColors.muted,
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
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
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
    return Consumer2<AuthProvider, PerfilProvider>(
      builder: (context, auth, perfilProv, _) {
        final username = auth.usuario?['username'] ?? 'Usuario';
        final inicial = username.isNotEmpty ? username[0].toUpperCase() : 'U';
        // Antes este badge siempre mostraba la inicial genérica, incluso
        // con Steam ya vinculado y una foto real disponible en el perfil —
        // inconsistente con la propia pantalla de Perfil, que sí la usa.
        final avatarSteam =
            perfilProv.perfil?['steam']?['avatar_url'] as String?;
        final tieneAvatarSteam = avatarSteam != null && avatarSteam.isNotEmpty;

        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(SteamRadii.sm),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                AvatarFoto(
                  size: 28,
                  fotoUrl: avatarSteam,
                  inicial: inicial,
                  semanticLabel: tieneAvatarSteam
                      ? 'Tu foto de perfil de Steam'
                      : null,
                ),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 110),
                  child: Text(
                    username,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: SteamColors.light,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
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
