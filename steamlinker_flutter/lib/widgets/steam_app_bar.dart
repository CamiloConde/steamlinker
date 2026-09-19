import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../theme/colors.dart';
import '../theme/radii.dart';
import 'app_logo_mark.dart';
import '../features/auth/providers/auth_provider.dart';
import '../features/perfil/providers/perfil_provider.dart';

class SteamAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  /// Si es null, muestra atrás cuando [Navigator.canPop] es true.
  final bool? showBack;
  /// Si es null, oculta el bloque de usuario en pantallas con botón atrás.
  final bool? showUserActions;
  final List<Widget>? actions;

  const SteamAppBar({
    super.key,
    required this.title,
    this.showBack,
    this.showUserActions,
    this.actions,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 1);

  bool _canPop(BuildContext context) {
    // Un modal bottom sheet o diálogo abierto ENCIMA de esta pantalla también
    // se registra como una ruta que se puede "pop" en el navigator — sin este
    // chequeo, abrir un modal hacía reaparecer la barra local (con flecha de
    // volver) en las pantallas de nivel superior, un parpadeo no deseado.
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return false;
    if (Navigator.of(context, rootNavigator: true).canPop()) return true;
    final router = GoRouter.maybeOf(context);
    if (router != null && router.canPop()) return true;
    return Navigator.of(context).canPop();
  }

  void _pop(BuildContext context) {
    final rootNav = Navigator.of(context, rootNavigator: true);
    if (rootNav.canPop()) {
      rootNav.pop();
      return;
    }
    final router = GoRouter.maybeOf(context);
    if (router != null && router.canPop()) {
      context.pop();
      return;
    }
    Navigator.of(context).maybePop();
  }

  /// Mismo breakpoint que `ResponsiveShell` (no se importa de ahí para evitar
  /// un ciclo de imports). En escritorio la nav superior global ya muestra
  /// usuario/logout, así que el bloque local de esta AppBar se suprime salvo
  /// que se pida explícitamente con [showUserActions].
  static const _kEscritorio = 768.0;

  @override
  Widget build(BuildContext context) {
    final canPop = _canPop(context);
    final useBack = showBack ?? canPop;
    final esEscritorio = MediaQuery.of(context).size.width >= _kEscritorio;
    final useUserActions =
        showUserActions ?? (!useBack && !esEscritorio);

    // Pantalla de nivel superior en escritorio: la nav global ya muestra el
    // nombre de la pestaña activa, así que repetirlo aquí (más el logo de
    // leading) es puro chrome redundante. Se funde con el fondo y solo deja
    // los íconos de acciones propios de la pantalla (Filtros, Refrescar,
    // Mis solicitudes, etc.), en vez de una segunda barra con título.
    final fundirConFondo = esEscritorio && !useBack;

    return AppBar(
      backgroundColor: fundirConFondo ? SteamColors.bgDeep : SteamColors.bgPanel,
      elevation: 0,
      automaticallyImplyLeading: false,
      leadingWidth: fundirConFondo ? 16 : (useBack ? 48 : 56),
      leading: fundirConFondo
          ? null
          : (useBack ? _BackLeading(onPressed: () => _pop(context)) : _LogoLeading()),
      bottom: fundirConFondo
          ? null
          : PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(height: 1, color: SteamColors.border),
            ),
      title: fundirConFondo
          ? null
          : Text(
              title,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: SteamColors.light,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
              ),
            ),
      actions: [
        ...?actions,
        if (useUserActions) _UserActions(),
        if (useUserActions || (actions != null && actions!.isNotEmpty))
          const SizedBox(width: 8)
        else
          const SizedBox(width: 16),
      ],
    );
  }
}

class _BackLeading extends StatelessWidget {
  final VoidCallback onPressed;

  const _BackLeading({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: 'Volver',
      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: SteamColors.light, size: 20),
    );
  }
}

class _LogoLeading extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: SteamColors.blue, width: 1.5),
        ),
        child: const AppLogoMark(size: 16, color: SteamColors.blue),
      ),
    );
  }
}

/// Solo el avatar (sin nombre ni "En línea" repetidos en cada pantalla): ese
/// bloque de texto era puro chrome redundante — ya hay una pestaña Perfil en
/// el bottom nav — y en pantallas con varios íconos de acción propios
/// (Descubrir, Publicaciones) empujaba el título fuera del espacio
/// disponible en móvil, a veces hasta dejarlo invisible. Ver HANDOFF.md.
class _UserActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthProvider, PerfilProvider>(
      builder: (context, auth, perfilProv, _) {
        final usuario = auth.usuario;
        final username = usuario?['username'] as String? ?? 'Usuario';
        final inicial = username.isNotEmpty ? username[0].toUpperCase() : 'U';
        // Mismo ajuste que el badge de escritorio: si ya hay Steam
        // vinculado, usar la foto real en vez de la inicial genérica.
        final avatarSteam = perfilProv.perfil?['steam']?['avatar_url'] as String?;
        final tieneAvatarSteam = avatarSteam != null && avatarSteam.isNotEmpty;

        return Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(SteamRadii.sm),
              gradient: tieneAvatarSteam
                  ? null
                  : const LinearGradient(
                      colors: [SteamColors.blue, SteamColors.teal],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              border: Border.all(color: SteamColors.blue, width: 1.5),
              image: tieneAvatarSteam
                  ? DecorationImage(image: NetworkImage(avatarSteam), fit: BoxFit.cover)
                  : null,
            ),
            child: tieneAvatarSteam
                ? null
                : Center(
                    child: Text(
                      inicial,
                      style: const TextStyle(
                        color: SteamColors.light,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
          ),
        );
      },
    );
  }
}
