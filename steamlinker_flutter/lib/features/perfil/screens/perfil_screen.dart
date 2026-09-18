import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../theme/colors.dart';
import '../../../theme/radii.dart';
import '../../../widgets/steam_app_bar.dart';
import '../../../widgets/steam_card.dart';
import '../../../widgets/steam_toast.dart';
import '../../../widgets/steam_buttons.dart';
import '../../../core/auth/session_actions.dart';
import '../../../core/auth/user_role.dart';
import '../../../core/navigation/app_navigator.dart';
import '../../../core/utils/estado_familia_helper.dart';
import '../../account/screens/account_settings_screen.dart';
import '../../amistad/providers/amistad_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../home/widgets/admin_panel_section.dart';
import '../../busqueda/screens/busqueda_screen.dart';
import '../../matches/providers/matches_provider.dart';
import '../../publicaciones/providers/publicaciones_provider.dart';
import '../perfil_scroll_signal.dart';
import '../providers/perfil_provider.dart';

class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  bool _inicializado = false;
  late PerfilProvider _perfilProv;
  final TextEditingController _steamController = TextEditingController();
  final _juegosKey = GlobalKey();
  bool _vinculandoSteam = false;
  bool _importandoSteam = false;
  bool _desvinculandoSteam = false;
  bool _iniciandoSteamLogin = false;
  bool _mostrarVinculacionManual = false;
  String? _steamError;

  @override
  void initState() {
    super.initState();
    perfilScrollSignal.addListener(_scrollAJuegos);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_inicializado) {
      _inicializado = true;
      _perfilProv = context.read<PerfilProvider>();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _cargarPerfil();
      });
    }
  }

  @override
  void dispose() {
    perfilScrollSignal.removeListener(_scrollAJuegos);
    _steamController.dispose();
    super.dispose();
  }

  void _scrollAJuegos() {
    final ctx = _juegosKey.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      alignment: 0.05,
    );
  }

  Future<void> _cargarPerfil() async {
    final auth = context.read<AuthProvider>();
    final perfilProv = _perfilProv;
    final usuario = auth.usuario;
    if (usuario == null) return;
    await Future.wait([
      perfilProv.cargarPerfil(usuario['id']),
      context.read<MatchesProvider>().cargarTodo(),
      context.read<PublicacionesProvider>().buscar(),
      context.read<AmistadProvider>().cargarTodo(),
    ]);
    if (!mounted) return;
  }

  Future<void> _vincularSteamCuenta() async {
    final steamId = _steamController.text.trim();
    if (steamId.isEmpty) {
      setState(() => _steamError = 'Ingresa tu SteamID o URL de Steam');
      return;
    }

    setState(() {
      _vinculandoSteam = true;
      _steamError = null;
    });

    final exito = await _perfilProv.vincularSteam(steamId);

    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _vinculandoSteam = false;
    });

    if (exito) {
      showSteamToastWithMessenger(
        messenger,
        'Cuenta Steam vinculada correctamente',
        SteamColors.green,
      );
      _steamController.clear();
    } else {
      showSteamToastWithMessenger(
        messenger,
        _perfilProv.error ?? 'No fue posible vincular Steam',
        Colors.red,
      );
      setState(() {
        _steamError = _perfilProv.error;
      });
    }
  }

  Future<void> _iniciarLoginSteam() async {
    setState(() {
      _iniciandoSteamLogin = true;
      _steamError = null;
    });

    final url = await _perfilProv.iniciarLoginSteam();

    if (!mounted) return;
    if (url == null) {
      final messenger = ScaffoldMessenger.of(context);
      setState(() => _iniciandoSteamLogin = false);
      showSteamToastWithMessenger(
        messenger,
        _perfilProv.error ?? 'No se pudo iniciar sesión con Steam',
        Colors.red,
      );
      return;
    }

    // Navega la pestaña actual a Steam (no una nueva) — Steam redirige de
    // vuelta a la app cuando el usuario termina, así que perder el estado
    // de esta pantalla no importa: el toast de resultado lo muestra
    // ResponsiveShell al volver, leyendo ?steam=ok/error de la URL.
    await launchUrl(Uri.parse(url), webOnlyWindowName: '_self');
    if (mounted) setState(() => _iniciandoSteamLogin = false);
  }

  Future<void> _importarBibliotecaSteam() async {
    setState(() {
      _importandoSteam = true;
      _steamError = null;
    });

    final mensaje = await _perfilProv.importarJuegosSteam();

    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _importandoSteam = false;
    });

    if (mensaje != null) {
      showSteamToastWithMessenger(messenger, mensaje, SteamColors.green);
    } else {
      showSteamToastWithMessenger(
        messenger,
        _perfilProv.error ?? 'No fue posible importar la biblioteca',
        Colors.red,
      );
      setState(() {
        _steamError = _perfilProv.error;
      });
    }
  }

  Future<void> _desvincularSteamCuenta() async {
    setState(() {
      _desvinculandoSteam = true;
      _steamError = null;
    });

    final exito = await _perfilProv.desvincularSteam();

    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _desvinculandoSteam = false;
    });

    if (exito) {
      showSteamToastWithMessenger(
        messenger,
        'Cuenta Steam desvinculada correctamente',
        SteamColors.green,
      );
    } else {
      showSteamToastWithMessenger(
        messenger,
        _perfilProv.error ?? 'No fue posible desvincular Steam',
        Colors.red,
      );
      setState(() {
        _steamError = _perfilProv.error;
      });
    }
  }

  Future<void> _toggleFavorito(Map<String, dynamic> juego) async {
    final exito = await _perfilProv.actualizarJuego(
      appid: juego['appid'],
      nombre: juego['nombre'],
      headerimg: juego['headerimg'] ?? '',
      capsuleimg: juego['capsuleimg'] ?? '',
      horas: juego['horas'] ?? 0,
      favorito: !(juego['favorito'] == true),
    );

    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    if (exito) {
      showSteamToastWithMessenger(
        messenger,
        juego['favorito'] == true
            ? 'Juego marcado como no favorito'
            : 'Juego marcado como favorito',
        SteamColors.green,
      );
    } else {
      showSteamToastWithMessenger(
        messenger,
        _perfilProv.error ?? 'No fue posible actualizar el juego',
        Colors.red,
      );
    }
  }

  Future<void> _editarHorasJuego(Map<String, dynamic> juego) async {
    final formKey = GlobalKey<FormState>();
    final controller = TextEditingController(text: '${juego['horas'] ?? 0}');
    final nuevoHoras = await showDialog<int?>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Editar horas de juego'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Horas jugadas',
                hintText: '0',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Ingresa un valor';
                }
                final numero = int.tryParse(value);
                if (numero == null || numero < 0) {
                  return 'Ingresa un número válido';
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                if (formKey.currentState?.validate() == true) {
                  Navigator.of(context).pop(int.parse(controller.text));
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );

    if (nuevoHoras == null) return;

    final exito = await _perfilProv.actualizarJuego(
      appid: juego['appid'],
      nombre: juego['nombre'],
      headerimg: juego['headerimg'] ?? '',
      capsuleimg: juego['capsuleimg'] ?? '',
      horas: nuevoHoras,
      favorito: juego['favorito'] == true,
    );

    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    if (exito) {
      showSteamToastWithMessenger(messenger, 'Horas actualizadas', SteamColors.green);
    } else {
      showSteamToastWithMessenger(
        messenger,
        _perfilProv.error ?? 'No fue posible actualizar horas',
        Colors.red,
      );
    }
  }

  Future<bool> _confirmarEliminarJuego(String nombre) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Eliminar juego'),
          content: Text('¿Deseas eliminar "$nombre" de tu perfil?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(
                'Eliminar',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );

    return confirmado == true;
  }

  Future<void> _eliminarJuego(int appid, String nombre) async {
    final confirmado = await _confirmarEliminarJuego(nombre);
    if (!confirmado) return;

    final exito = await _perfilProv.eliminarJuego(appid);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    if (exito) {
      showSteamToastWithMessenger(messenger, 'Juego eliminado del perfil', SteamColors.green);
    } else {
      showSteamToastWithMessenger(
        messenger,
        _perfilProv.error ?? 'No fue posible eliminar el juego',
        Colors.red,
      );
    }
  }

  Widget _buildGameListTile(Map<String, dynamic> juego) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(SteamRadii.sm),
            border: juego['favorito'] == true
                ? Border.all(color: SteamColors.red, width: 2)
                : null,
            image:
                juego['headerimg'] != null &&
                    juego['headerimg'].toString().isNotEmpty
                ? DecorationImage(
                    image: NetworkImage(juego['headerimg']),
                    fit: BoxFit.cover,
                  )
                : null,
            color: SteamColors.bgPanel,
          ),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                juego['nombre'] ?? 'Juego',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: SteamColors.light,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 6),
            _BadgeOrigenJuego(esSteam: juego['origen'] == 'steam'),
          ],
        ),
        subtitle: Text(
          'Horas: ${juego['horas']} • ${juego['favorito'] == true ? '⭐ Favorito' : 'No favorito'}',
          style: const TextStyle(color: SteamColors.textSec, fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                juego['favorito'] == true
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                color: juego['favorito'] == true
                    ? SteamColors.red
                    : SteamColors.muted,
              ),
              onPressed: () => _toggleFavorito(juego),
              tooltip: juego['favorito'] == true
                  ? 'Remover de favoritos'
                  : 'Agregar a favoritos',
            ),
            IconButton(
              icon: const Icon(Icons.edit, color: SteamColors.blue),
              onPressed: () => _editarHorasJuego(juego),
              tooltip: 'Editar horas',
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: SteamColors.red),
              onPressed: () =>
                  _eliminarJuego(juego['appid'], juego['nombre'] ?? 'el juego'),
              tooltip: 'Eliminar juego',
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final perfilProv = context.watch<PerfilProvider>();
    final auth = context.watch<AuthProvider>();
    final matchesProv = context.watch<MatchesProvider>();
    final publicacionesProv = context.watch<PublicacionesProvider>();
    final amistadProv = context.watch<AmistadProvider>();
    final perfil = perfilProv.perfil;
    final esAdmin = esUsuarioAdmin(auth.usuario) || esUsuarioAdmin(perfil);

    final miId = auth.usuario?['id'] as int?;
    final misPublicaciones = publicacionesProv.publicaciones
        .where((p) => p is Map && p['id_usu'] == miId)
        .map((p) => Map<String, dynamic>.from(p as Map))
        .toList();
    final estadoFamilia = calcularEstadoFamilia(
      misPublicaciones: misPublicaciones,
      matchesEnviados: matchesProv.enviados,
      todasPublicaciones: publicacionesProv.publicaciones,
    );

    // En escritorio la nav superior global ya tiene su propio botón de
    // cerrar sesión — mostrarlo aquí también duplicaba el icono.
    final esEscritorio = MediaQuery.of(context).size.width >= 768;
    final puedeVolver = Navigator.of(context).canPop();

    // PerfilScreen SIEMPRE se construye como pestaña del IndexedStack
    // (ResponsiveShell/MainShell) o vía _ir(), que en escritorio usa
    // onNavigateIndex (cambia de pestaña) en vez de pushear -- nunca se
    // pushea sola en escritorio, así que a diferencia de Home/Descubrir/
    // Publicaciones/Amigos no hace falta un esPestana explícito. Antes
    // esta pantalla se quedó fuera de esa ronda de arreglos y seguía
    // mostrando el AppBar "fundida con el fondo" vacía en escritorio --
    // el hueco que reportó el usuario. Ver HANDOFF.md.
    return Scaffold(
      backgroundColor: SteamColors.bgDeep,
      appBar: (esEscritorio && !puedeVolver)
          ? null
          : SteamAppBar(
              title: puedeVolver ? 'MIS JUEGOS' : 'PERFIL',
              showUserActions: puedeVolver,
              actions: puedeVolver
                  ? null
                  : [
                      IconButton(
                        icon: const Icon(Icons.logout, color: SteamColors.muted),
                        tooltip: 'Cerrar sesión',
                        onPressed: () => confirmarYCerrarSesion(context),
                      ),
                    ],
            ),
      body: perfilProv.cargando && perfil == null
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(SteamColors.blue),
              ),
            )
          : perfil == null
          ? Center(
              child: Text(
                perfilProv.error ?? 'No se pudo cargar el perfil',
                style: const TextStyle(color: SteamColors.light),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PerfilHeader(
                    perfil: perfil,
                    juegosCount: perfilProv.juegos
                        .where((j) => j['origen'] == 'steam')
                        .length,
                    amigosCount: amistadProv.amigos.length,
                    estadoFamilia: estadoFamilia,
                    onConfiguracion: () {
                      pushAppScreen(context, const AccountSettingsScreen());
                    },
                    onSalir: () => confirmarYCerrarSesion(context),
                  ),
                  if (esAdmin) ...[
                    const SizedBox(height: 16),
                    const AdminPanelSection(),
                  ],
                  const SizedBox(height: 16),
                  SteamCard(
                    icon: Icons.verified_user,
                    title: perfil['steam'] != null
                        ? 'Steam conectado'
                        : 'Vincular Steam',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (perfil['steam'] != null) ...[
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundImage:
                                    perfil['steam']['avatar_url'] != null
                                    ? NetworkImage(
                                        perfil['steam']['avatar_url'],
                                      )
                                    : null,
                                backgroundColor: SteamColors.bgPanel,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      perfil['steam']['username_steperfil'] ??
                                          'Steam',
                                      style: const TextStyle(
                                        color: SteamColors.light,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: SelectableText(
                                            perfil['steam']['perfil_url'] ?? '',
                                            style: const TextStyle(
                                              color: SteamColors.blue,
                                              fontSize: 12,
                                            ),
                                            scrollPhysics:
                                                const NeverScrollableScrollPhysics(),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.copy,
                                            size: 18,
                                            color: SteamColors.textSec,
                                          ),
                                          tooltip: 'Copiar enlace de Steam',
                                          onPressed: () {
                                            final url =
                                                perfil['steam']['perfil_url'] ??
                                                '';
                                            if (url.isNotEmpty) {
                                              Clipboard.setData(
                                                ClipboardData(text: url),
                                              );
                                              showSteamToast(
                                                context,
                                                'Enlace copiado',
                                                SteamColors.green,
                                              );
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (_steamError != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(
                                _steamError!,
                                style: const TextStyle(
                                  color: SteamColors.red,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          Row(
                            children: [
                              Expanded(
                                child: SteamButtonPrimary(
                                  label: _importandoSteam
                                      ? 'Importando...'
                                      : 'Importar biblioteca',
                                  icon: Icons.download,
                                  onTap: _importandoSteam
                                      ? null
                                      : (ctx) => _importarBibliotecaSteam(),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SteamButtonOutline(
                            label: _desvinculandoSteam
                                ? 'Desvinculando...'
                                : 'Desvincular Steam',
                            onTap: _desvinculandoSteam
                                ? null
                                : () => _desvincularSteamCuenta(),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Tu perfil Steam debe ser público para que podamos importar tu biblioteca. Si tu perfil es privado, solo podrás vincular la cuenta pero no importar juegos.',
                            style: TextStyle(
                              color: SteamColors.textSec,
                              fontSize: 12,
                            ),
                          ),
                        ] else ...[
                          if (_steamError != null) ...[
                            Text(
                              _steamError!,
                              style: const TextStyle(
                                color: SteamColors.red,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                          SteamButtonPrimary(
                            label: _iniciandoSteamLogin
                                ? 'Conectando con Steam...'
                                : 'Iniciar sesión con Steam',
                            icon: Icons.login,
                            onTap: _iniciandoSteamLogin
                                ? null
                                : (ctx) => _iniciarLoginSteam(),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Tu perfil Steam debe ser público para que podamos importar tu biblioteca. Si tu perfil es privado, solo podrás vincular la cuenta pero no importar juegos.',
                            style: TextStyle(
                              color: SteamColors.textSec,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Center(
                            child: TextButton(
                              onPressed: () => setState(
                                () => _mostrarVinculacionManual = !_mostrarVinculacionManual,
                              ),
                              child: Text(
                                _mostrarVinculacionManual
                                    ? 'Ocultar vinculación manual'
                                    : '¿No funciona? Vincula pegando tu SteamID o URL',
                                style: const TextStyle(fontSize: 12, color: SteamColors.muted),
                              ),
                            ),
                          ),
                          if (_mostrarVinculacionManual) ...[
                            const SizedBox(height: 4),
                            TextField(
                              controller: _steamController,
                              style: const TextStyle(color: SteamColors.light),
                              decoration: InputDecoration(
                                labelText: 'SteamID o URL de Steam',
                                hintText:
                                    'steamcommunity.com/id/usuario o steamcommunity.com/profiles/765... ',
                                filled: true,
                                fillColor: SteamColors.bgInput,
                              ),
                            ),
                            const SizedBox(height: 10),
                            SteamButtonOutline(
                              label: _vinculandoSteam
                                  ? 'Vinculando...'
                                  : 'Vincular manualmente',
                              onTap: _vinculandoSteam
                                  ? null
                                  : () => _vincularSteamCuenta(),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SteamCard(
                    icon: Icons.search,
                    title: 'Buscar juegos',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Usa la búsqueda para encontrar juegos en Steam y agregarlos rápido a tu biblioteca.',
                          style: TextStyle(
                            color: SteamColors.textSec,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SteamButtonPrimary(
                          label: 'Ir a búsqueda',
                          icon: Icons.search,
                          onTap: (ctx) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const BusquedaScreen(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SteamCard(
                    key: _juegosKey,
                    icon: Icons.videogame_asset_outlined,
                    title: 'Juegos (${perfilProv.juegos.length})',
                    child: Column(
                      children: perfilProv.juegos.isEmpty
                          ? [
                              const Text(
                                'No se han agregado juegos todavía.',
                                style: TextStyle(color: SteamColors.textSec),
                              ),
                            ]
                          : [
                              // Juegos favoritos
                              ...perfilProv.juegos
                                  .where((j) => j['favorito'] == true)
                                  .map((juego) {
                                    return _buildGameListTile(juego);
                                  }),
                              // Divisor si hay favoritos y no favoritos
                              if (perfilProv.juegos.any(
                                    (j) => j['favorito'] == true,
                                  ) &&
                                  perfilProv.juegos.any(
                                    (j) => j['favorito'] != true,
                                  ))
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  child: Divider(
                                    color: SteamColors.border.withAlpha(77),
                                    height: 1,
                                  ),
                                ),
                              // Juegos no favoritos
                              ...perfilProv.juegos
                                  .where((j) => j['favorito'] != true)
                                  .map((juego) {
                                    return _buildGameListTile(juego);
                                  }),
                            ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _PerfilHeader extends StatelessWidget {
  final Map<String, dynamic> perfil;
  final int juegosCount;
  final int amigosCount;
  final EstadoFamilia estadoFamilia;
  final VoidCallback onConfiguracion;
  final VoidCallback onSalir;

  const _PerfilHeader({
    required this.perfil,
    required this.juegosCount,
    required this.amigosCount,
    required this.estadoFamilia,
    required this.onConfiguracion,
    required this.onSalir,
  });

  @override
  Widget build(BuildContext context) {
    final steam = perfil['steam'] as Map<String, dynamic>?;
    final avatarUrl = steam?['avatar_url'] as String?;
    final username = (perfil['username'] as String?) ?? 'Usuario';
    final inicial = username.isNotEmpty ? username[0].toUpperCase() : '?';
    final descripcion = (perfil['descrip'] as String?)?.trim();

    return Container(
      decoration: BoxDecoration(
        color: SteamColors.bgCard,
        borderRadius: BorderRadius.circular(SteamRadii.sm),
        border: Border.all(color: SteamColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Banner + avatar superpuesto ─────────────────────────────
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                height: 92,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [SteamColors.blue, SteamColors.teal],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              Positioned(
                left: 16,
                bottom: -32,
                child: Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: SteamColors.bgCard, width: 4),
                    gradient: avatarUrl == null
                        ? const LinearGradient(
                            colors: [SteamColors.blue, SteamColors.teal],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    image: avatarUrl != null
                        ? DecorationImage(
                            image: NetworkImage(avatarUrl),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: avatarUrl == null
                      ? Center(
                          child: Text(
                            inicial,
                            style: const TextStyle(
                              color: SteamColors.light,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        )
                      : null,
                ),
              ),
              if (steam != null)
                Positioned(
                  left: 60,
                  bottom: -32,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: SteamColors.blue,
                      border: Border.all(color: SteamColors.bgCard, width: 3),
                    ),
                    child: const Icon(
                      Icons.verified_rounded,
                      size: 13,
                      color: SteamColors.bgDeep,
                    ),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  username,
                  style: const TextStyle(
                    color: SteamColors.light,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (descripcion != null && descripcion.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    descripcion,
                    style: const TextStyle(
                      color: SteamColors.textSec,
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  perfil['pais'] ?? 'País no especificado',
                  style: const TextStyle(color: SteamColors.muted, fontSize: 12),
                ),
                const SizedBox(height: 14),
                _StatGrid(
                  reputacion: perfil['repu'],
                  totalCalificaciones: perfil['totalrating'],
                  juegosCount: juegosCount,
                  amigosCount: amigosCount,
                  estadoFamilia: estadoFamilia,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: SteamButtonOutline(
                        label: 'Configuración',
                        icon: Icons.settings_outlined,
                        compact: true,
                        onTap: onConfiguracion,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onSalir,
                        icon: const Icon(Icons.logout, size: 15),
                        label: const Text('Salir', style: TextStyle(fontSize: 13)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: SteamColors.red,
                          side: const BorderSide(color: SteamColors.red),
                          minimumSize: const Size(72, 36),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Grid de 4 celdas con números monoespaciados (wireframe turno 4, opción
/// 4b): reemplaza los chips de País/Reputación/Juegos por las métricas que
/// alguien realmente mira antes de mandar un match — es la sensación
/// SteamDB que ya tiene el resto de la app.
class _StatGrid extends StatelessWidget {
  final dynamic reputacion;
  final dynamic totalCalificaciones;
  final int juegosCount;
  final int amigosCount;
  final EstadoFamilia estadoFamilia;

  const _StatGrid({
    required this.reputacion,
    required this.totalCalificaciones,
    required this.juegosCount,
    required this.amigosCount,
    required this.estadoFamilia,
  });

  @override
  Widget build(BuildContext context) {
    final rep = double.tryParse('$reputacion') ?? 0.0;
    final totalRep = totalCalificaciones ?? 0;

    String familiaValor;
    Color familiaColor;
    if (estadoFamilia.total != null) {
      familiaValor = '${estadoFamilia.ocupados ?? 0}/${estadoFamilia.total}';
      familiaColor = SteamColors.teal;
    } else if (estadoFamilia.etiqueta == 'En una familia') {
      familiaValor = 'Sí';
      familiaColor = SteamColors.teal;
    } else {
      familiaValor = '—';
      familiaColor = SteamColors.light;
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: SteamColors.border),
        borderRadius: BorderRadius.circular(SteamRadii.sm),
      ),
      clipBehavior: Clip.antiAlias,
      child: Wrap(
        children: [
          _StatCell(
            label: 'REPUTACIÓN',
            valor: rep.toStringAsFixed(1),
            sufijo: '/5 · $totalRep',
          ),
          _StatCell(label: 'JUEGOS VERIFICADOS', valor: '$juegosCount'),
          _StatCell(label: 'FAMILIA', valor: familiaValor, color: familiaColor),
          _StatCell(label: 'AMIGOS', valor: '$amigosCount'),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  final String label;
  final String valor;
  final String? sufijo;
  final Color color;

  const _StatCell({
    required this.label,
    required this.valor,
    this.sufijo,
    this.color = SteamColors.light,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 110),
      width: 150,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        color: SteamColors.bgPanel,
        border: Border(
          left: BorderSide(color: SteamColors.border),
          top: BorderSide(color: SteamColors.border),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: SteamColors.muted,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 2),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: valor,
                  style: TextStyle(
                    color: color,
                    fontSize: 19,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (sufijo != null)
                  TextSpan(
                    text: ' $sufijo',
                    style: const TextStyle(
                      color: SteamColors.muted,
                      fontSize: 12,
                      fontFamily: 'monospace',
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

/// Distingue un juego importado de verdad desde la API de Steam (origen
/// confiable) de uno agregado a mano con el buscador (el usuario puede
/// escribir cualquier juego ahi sin poseerlo realmente). Antes de esto
/// ambos se veian identicos y el conteo de "Juegos verificados" los
/// mezclaba -- ver HANDOFF.md.
class _BadgeOrigenJuego extends StatelessWidget {
  final bool esSteam;
  const _BadgeOrigenJuego({required this.esSteam});

  @override
  Widget build(BuildContext context) {
    final color = esSteam ? SteamColors.teal : SteamColors.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(31),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withAlpha(102)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            esSteam ? Icons.verified : Icons.edit_outlined,
            size: 11,
            color: color,
          ),
          const SizedBox(width: 3),
          Text(
            esSteam ? 'STEAM' : 'MANUAL',
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}
