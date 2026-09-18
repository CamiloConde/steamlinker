// Punto de entrada de la aplicacion Steamlinker
// Configura providers, rutas y tema visual

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/config/app_config.dart';
import 'package:provider/provider.dart';
import 'core/navigation/app_router.dart';
import 'core/network/api_bootstrap.dart';
import 'core/network/api_client.dart';
import 'core/providers/locale_provider.dart';
import 'features/auth/providers/auth_provider.dart';
import 'package:go_router/go_router.dart';
import 'features/amistad/providers/amistad_provider.dart';
import 'features/calificaciones/providers/calificaciones_provider.dart';
import 'features/reportes/providers/reportes_provider.dart';
import 'features/chat/providers/chat_provider.dart';
import 'features/matches/providers/matches_provider.dart';
import 'features/notifications/providers/notificaciones_provider.dart';
import 'features/perfil/providers/perfil_provider.dart';
import 'features/publicaciones/providers/publicaciones_provider.dart';
import 'l10n/app_localizations.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ApiClient.init();
  if (kDebugMode || kProfileMode) {
    debugPrint('Steamlinker → API: ${AppConfig.apiBaseUrl}');
  }
  runApp(const SteamlinkerApp());
}

class SteamlinkerApp extends StatefulWidget {
  const SteamlinkerApp({super.key});

  @override
  State<SteamlinkerApp> createState() => _SteamlinkerAppState();
}

class _SteamlinkerAppState extends State<SteamlinkerApp> {
  late final AuthProvider _auth;
  late final GoRouter _router;
  late final LocaleProvider _locale;

  @override
  void initState() {
    super.initState();
    _auth = AuthProvider()..verificarSesion();
    _router = createAppRouter(_auth);
    _locale = LocaleProvider()..cargar();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _auth),
        ChangeNotifierProvider.value(value: _locale),
        ChangeNotifierProvider(create: (_) => PerfilProvider()),
        ChangeNotifierProvider(create: (_) => PublicacionesProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => MatchesProvider()),
        ChangeNotifierProvider(create: (_) => AmistadProvider()),
        ChangeNotifierProvider(create: (_) => CalificacionesProvider()),
        ChangeNotifierProvider(create: (_) => ReportesProvider()),
        ChangeNotifierProvider(create: (_) => NotificacionesProvider()),
      ],
      child: ApiBootstrap(
        child: Consumer<LocaleProvider>(
          builder: (context, localeProv, _) {
            return MaterialApp.router(
              title: 'SteamMatch',
              debugShowCheckedModeBanner: false,
              theme: SteamTheme.theme,
              routerConfig: _router,
              locale: localeProv.locale,
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
            );
          },
        ),
      ),
    );
  }
}