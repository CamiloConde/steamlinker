import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/account/screens/account_settings_screen.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/home/screens/responsive_shell.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

GoRouter createAppRouter(AuthProvider auth) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/login',
    refreshListenable: auth,
    redirect: (context, state) {
      final path = state.matchedLocation;
      final enLogin = path == '/login';
      if (auth.autenticado && enLogin) return '/home';
      if (!auth.autenticado && !enLogin) return '/login';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const ResponsiveShell(),
      ),
      GoRoute(
        path: '/configuracion',
        builder: (context, state) => const AccountSettingsScreen(),
      ),
    ],
  );
}
