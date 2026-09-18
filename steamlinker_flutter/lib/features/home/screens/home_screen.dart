import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/pais_util.dart';
import '../../../core/constants/publicacion_constants.dart';
import '../../../core/utils/estado_familia_helper.dart';
import '../../../theme/colors.dart';
import '../../../theme/radii.dart';
import '../../../widgets/desktop_body_width.dart';
import '../../../widgets/steam_app_bar.dart';
import '../../../core/auth/session_actions.dart';
import '../../auth/providers/auth_provider.dart';
import '../../matches/providers/matches_provider.dart';
import '../../perfil/providers/perfil_provider.dart';
import '../../perfil/screens/perfil_screen.dart';
import '../../perfil/widgets/apoyar_proyecto_card.dart';
import '../../publicaciones/providers/publicaciones_provider.dart';
import '../../publicaciones/screens/crear_publicacion_screen.dart';
import '../../publicaciones/screens/publicaciones_screen.dart';
import '../../usuarios/screens/usuario_detalle_screen.dart';

/// Inicio como bandeja de acciones pendientes (wireframe turno 2, opción
/// 2a, confirmada por el usuario): nada de atajos que repiten la nav
/// superior — solo lo que requiere que el usuario haga algo (aceptar/ver
/// solicitudes, vincular Steam, cerrar publicaciones llenas).
class HomeScreen extends StatefulWidget {
  /// Cuando se embebe en el sidebar de escritorio (ResponsiveShell), las
  /// acciones de esta pantalla cambian de sección en vez de empujar una
  /// pantalla nueva sobre el sidebar. En móvil queda null y se usa
  /// Navigator.push como siempre.
  final ValueChanged<int>? onNavigateIndex;

  const HomeScreen({super.key, this.onNavigateIndex});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _inicializado = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_inicializado) {
      _inicializado = true;
      _cargar();
    }
  }

  Future<void> _cargar() async {
    final auth = context.read<AuthProvider>();
    final perfil = context.read<PerfilProvider>();
    final id = auth.usuario?['id'] as int?;
    await Future.wait([
      if (id != null) perfil.cargarPerfil(id),
      context.read<MatchesProvider>().cargarTodo(),
      context.read<PublicacionesProvider>().buscar(),
    ]);
  }

  void _ir(int indiceEscritorio, Widget pantalla) {
    final onNavigateIndex = widget.onNavigateIndex;
    if (onNavigateIndex != null) {
      onNavigateIndex(indiceEscritorio);
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => pantalla));
  }

  @override
  Widget build(BuildContext context) {
    final esEscritorio = MediaQuery.of(context).size.width >= 768;

    final auth = context.watch<AuthProvider>();
    final perfilProv = context.watch<PerfilProvider>();
    final matchesProv = context.watch<MatchesProvider>();
    final publicacionesProv = context.watch<PublicacionesProvider>();

    final usuario = auth.usuario;
    if (usuario == null) {
      return Scaffold(
        backgroundColor: SteamColors.bgDeep,
        appBar: const SteamAppBar(title: 'INICIO'),
        body: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(SteamColors.blue),
          ),
        ),
      );
    }

    final miId = usuario['id'] as int?;
    final steamVinculado = perfilProv.perfil?['steam'] != null;

    final pendientes = matchesProv.recibidos
        .where((m) => m['estado_match'] == 'Pendiente')
        .toList();

    final misPublicaciones = publicacionesProv.publicaciones
        .where((p) => p is Map && p['id_usu'] == miId)
        .map((p) => Map<String, dynamic>.from(p as Map))
        .toList();

    final estadoFamilia = calcularEstadoFamilia(
      misPublicaciones: misPublicaciones,
      matchesEnviados: matchesProv.enviados,
      todasPublicaciones: publicacionesProv.publicaciones,
    );

    final nadaPendiente =
        pendientes.isEmpty && misPublicaciones.isEmpty && steamVinculado;

    return Scaffold(
      backgroundColor: SteamColors.bgDeep,
      appBar: SteamAppBar(
        title: 'INICIO',
        actions: esEscritorio
            ? null
            : [
                IconButton(
                  icon: const Icon(Icons.logout, color: SteamColors.muted),
                  tooltip: 'Cerrar sesión',
                  onPressed: () => confirmarYCerrarSesion(context),
                ),
              ],
      ),
      body: RefreshIndicator(
        color: SteamColors.blue,
        backgroundColor: SteamColors.bgDeep,
        onRefresh: _cargar,
        child: DesktopBodyWidth(
          maxWidth: 760,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Tarjeta de Bienvenida ────────────────────────────
                Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [SteamColors.blue, SteamColors.teal],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(SteamRadii.sm),
                    border: Border.all(color: SteamColors.blue, width: 1),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Bienvenido',
                            style: TextStyle(
                              color: SteamColors.textSec,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            usuario['username'] ?? 'Usuario',
                            style: const TextStyle(
                              color: SteamColors.light,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(SteamRadii.sm),
                          color: SteamColors.blue.withAlpha(51),
                          border: Border.all(color: SteamColors.blue, width: 2),
                        ),
                        child: Center(
                          child: Text(
                            (usuario['username'] as String).isNotEmpty
                                ? (usuario['username'] as String)[0].toUpperCase()
                                : 'U',
                            style: const TextStyle(
                              color: SteamColors.light,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── TU ESTADO ────────────────────────────────────────
                _TarjetaEstado(
                  estado: estadoFamilia.etiqueta,
                  publicacionesAbiertas: misPublicaciones.length,
                ),
                if (!steamVinculado) ...[
                  const SizedBox(height: 10),
                  _TarjetaSteamNoVinculado(onVincular: () => _ir(7, const PerfilScreen())),
                ],

                if (pendientes.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _Titulo('SOLICITUDES PENDIENTES · ${pendientes.length}'),
                  const SizedBox(height: 10),
                  for (final m in pendientes)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _FilaSolicitud(
                        match: Map<String, dynamic>.from(m as Map),
                        onAceptar: () async {
                          await matchesProv.responder(m['id_match'], 'Aceptada');
                          if (!context.mounted) return;
                          await _cargar();
                        },
                        onRechazar: () async {
                          await matchesProv.responder(m['id_match'], 'Rechazada');
                        },
                        onVerPerfil: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => UsuarioDetalleScreen(
                              userId: m['id_solicitante'] as int,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],

                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const _Titulo('TUS PUBLICACIONES ABIERTAS'),
                    TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const CrearPublicacionScreen()),
                      ),
                      child: const Text('Crear publicación'),
                    ),
                  ],
                ),
                if (misPublicaciones.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text(
                      'No tienes publicaciones abiertas.',
                      style: TextStyle(color: SteamColors.textSec, fontSize: 13),
                    ),
                  )
                else
                  for (final p in misPublicaciones)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _FilaPublicacionPropia(
                        publicacion: p,
                        solicitudesNuevas: pendientes
                            .where((m) => m['id_publi'] == p['id_publi'])
                            .length,
                        onCerrar: () async {
                          await publicacionesProv.cerrar(p['id_publi'] as int);
                        },
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const PublicacionesScreen()),
                        ),
                      ),
                    ),

                if (nadaPendiente) ...[
                  const SizedBox(height: 24),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Column(
                        children: [
                          const Text(
                            'Todo al día.',
                            style: TextStyle(
                              color: SteamColors.light,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextButton(
                            onPressed: () => _ir(2, const PublicacionesScreen()),
                            child: const Text('Ver publicaciones de la comunidad'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 24),
                const ApoyarProyectoCard(),

                const SizedBox(height: 28),
                const _FooterInicio(),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Pie de página de Inicio: qué es SteamMatch y el descargo de no
/// afiliación a Valve (pedido aparte del rediseño de wireframes, ver
/// HANDOFF.md). Vive aquí y no en cada pantalla porque Inicio es el punto
/// de entrada de la app.
class _FooterInicio extends StatelessWidget {
  const _FooterInicio();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: SteamColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SteamMatch',
            style: TextStyle(
              color: SteamColors.textSec,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Conectamos gamers para formar familias de Steam y encontrar '
            'compañeros de juego, a partir de tu biblioteca verificada. '
            'Un proyecto independiente, no un servicio oficial de Steam.',
            style: TextStyle(color: SteamColors.muted, fontSize: 12, height: 1.5),
          ),
          const SizedBox(height: 10),
          const Text(
            'No afiliados a Valve Corporation. Steam es una marca registrada '
            'de Valve Corporation.',
            style: TextStyle(color: SteamColors.muted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _Titulo extends StatelessWidget {
  final String texto;
  const _Titulo(this.texto);

  @override
  Widget build(BuildContext context) {
    return Text(
      texto,
      style: const TextStyle(
        color: SteamColors.muted,
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.9,
      ),
    );
  }
}

class _TarjetaEstado extends StatelessWidget {
  final String estado;
  final int publicacionesAbiertas;

  const _TarjetaEstado({required this.estado, required this.publicacionesAbiertas});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SteamColors.bgCard,
        borderRadius: BorderRadius.circular(SteamRadii.sm),
        border: Border.all(color: SteamColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Titulo('TU ESTADO'),
          const SizedBox(height: 6),
          Text(
            estado,
            style: const TextStyle(
              color: SteamColors.light,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            publicacionesAbiertas == 1
                ? '1 publicación abierta'
                : '$publicacionesAbiertas publicaciones abiertas',
            style: const TextStyle(color: SteamColors.textSec, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _TarjetaSteamNoVinculado extends StatelessWidget {
  final VoidCallback onVincular;
  const _TarjetaSteamNoVinculado({required this.onVincular});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SteamColors.bgCard,
        borderRadius: BorderRadius.circular(SteamRadii.sm),
        border: Border.all(color: SteamColors.blue),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'STEAM NO VINCULADO',
                  style: TextStyle(
                    color: SteamColors.blue,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.9,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Necesario para publicar o matchear en Familia',
                  style: TextStyle(color: SteamColors.light, fontSize: 13.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: onVincular,
            style: ElevatedButton.styleFrom(
              backgroundColor: SteamColors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Vincular'),
          ),
        ],
      ),
    );
  }
}

class _FilaSolicitud extends StatelessWidget {
  final Map<String, dynamic> match;
  final VoidCallback onAceptar;
  final VoidCallback onRechazar;
  final VoidCallback onVerPerfil;

  const _FilaSolicitud({
    required this.match,
    required this.onAceptar,
    required this.onRechazar,
    required this.onVerPerfil,
  });

  @override
  Widget build(BuildContext context) {
    final username = (match['solicitante_username'] as String?) ?? 'Alguien';
    final tipo = match['tipo_publi'] as String?;
    final accion = tipo == 'busco_familia' || tipo == 'busco_miembros'
        ? 'quiere unirse a tu publicación'
        : tipo == 'busco_companero'
            ? 'quiere jugar contigo'
            : 'quiere conectar contigo';

    final partes = <String>[];
    if (tipo != null) partes.add(PublicacionConstants.etiquetaTipo(tipo).toUpperCase());
    final total = match['cupos_totales'] as int?;
    if (total != null) {
      partes.add('${match['cupos_ocupados'] ?? 0}/$total cupos');
    } else if (match['titulo_publi'] != null) {
      partes.add(match['titulo_publi'] as String);
    }
    final rep = match['solicitante_reputacion'];
    if (rep != null) {
      partes.add('★ ${double.tryParse('$rep')?.toStringAsFixed(1) ?? rep}');
    }
    final pais = match['solicitante_pais'] as String?;
    if (pais != null && pais.isNotEmpty) partes.add(PaisUtil.codigoANombre(pais));

    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: SteamColors.bgCard,
        borderRadius: BorderRadius.circular(SteamRadii.sm),
        border: Border.all(color: SteamColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [SteamColors.blue, SteamColors.teal],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              username.isNotEmpty ? username[0].toUpperCase() : '?',
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: username,
                        style: const TextStyle(
                          color: SteamColors.light,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextSpan(
                        text: ' $accion',
                        style: const TextStyle(color: SteamColors.textSec, fontWeight: FontWeight.w400),
                      ),
                    ],
                  ),
                ),
                if (partes.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      partes.join(' · '),
                      style: const TextStyle(color: SteamColors.muted, fontSize: 11.5),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: onAceptar,
            style: ElevatedButton.styleFrom(
              backgroundColor: SteamColors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: const Text('Aceptar', style: TextStyle(fontSize: 12.5)),
          ),
          const SizedBox(width: 6),
          OutlinedButton(
            onPressed: onVerPerfil,
            style: OutlinedButton.styleFrom(
              foregroundColor: SteamColors.textSec,
              side: const BorderSide(color: SteamColors.border),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            child: const Text('Ver perfil', style: TextStyle(fontSize: 12.5)),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: SteamColors.red),
            tooltip: 'Rechazar',
            onPressed: onRechazar,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }
}

class _FilaPublicacionPropia extends StatelessWidget {
  final Map<String, dynamic> publicacion;
  final int solicitudesNuevas;
  final VoidCallback onCerrar;
  final VoidCallback onTap;

  const _FilaPublicacionPropia({
    required this.publicacion,
    required this.solicitudesNuevas,
    required this.onCerrar,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final total = publicacion['cupos_totales'] as int?;
    final ocupados = publicacion['cupos_ocupados'] as int? ?? 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(SteamRadii.sm),
        child: Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: SteamColors.bgCard,
            borderRadius: BorderRadius.circular(SteamRadii.sm),
            border: Border.all(color: SteamColors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      PublicacionConstants.etiquetaTipo(publicacion['tipo_publi'] as String?)
                          .toUpperCase(),
                      style: const TextStyle(
                        color: SteamColors.light,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      solicitudesNuevas > 0
                          ? '$solicitudesNuevas solicitud${solicitudesNuevas == 1 ? '' : 'es'} nueva${solicitudesNuevas == 1 ? '' : 's'}'
                          : (publicacion['titulo_publi'] as String? ?? ''),
                      style: const TextStyle(color: SteamColors.muted, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
              if (total != null) ...[
                SizedBox(
                  width: 110,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('CUPOS', style: TextStyle(color: SteamColors.textSec, fontSize: 10)),
                          Text('$ocupados/$total',
                              style: const TextStyle(color: SteamColors.textSec, fontSize: 10)),
                        ],
                      ),
                      const SizedBox(height: 3),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: total > 0 ? (ocupados / total).clamp(0, 1) : 0,
                          minHeight: 5,
                          backgroundColor: SteamColors.bgInput,
                          valueColor: const AlwaysStoppedAnimation(SteamColors.teal),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
              ],
              OutlinedButton(
                onPressed: onCerrar,
                style: OutlinedButton.styleFrom(
                  foregroundColor: SteamColors.textSec,
                  side: const BorderSide(color: SteamColors.border),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                child: const Text('Cerrar', style: TextStyle(fontSize: 12.5)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
