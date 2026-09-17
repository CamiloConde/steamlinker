import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../widgets/desktop_body_width.dart';
import '../../../core/constants/pais_util.dart';
import '../../../core/constants/publicacion_constants.dart';
import '../../../core/utils/relacion_helper.dart';
import '../../../theme/colors.dart';
import '../../../theme/radii.dart';
import '../../../widgets/drop_field.dart';
import '../../../widgets/publicacion_card.dart';
import '../../../widgets/steam_app_bar.dart';
import '../../amistad/providers/amistad_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../chat/providers/chat_provider.dart';
import '../../chat/screens/chat_conversation_screen.dart';
import '../../matches/providers/matches_provider.dart';
import '../../matches/screens/matches_screen.dart';
import '../../perfil/providers/perfil_provider.dart';
import '../providers/publicaciones_provider.dart';
import '../../usuarios/screens/usuario_detalle_screen.dart';
import 'crear_publicacion_screen.dart';
import 'publicacion_detalle_screen.dart';

/// Por debajo de este ancho se usa el layout móvil de una sola columna con
/// FAB. Igual al breakpoint de `ResponsiveShell` (no se importa de ahí para
/// evitar un ciclo de imports).
const _kEscritorio = 768.0;

class PublicacionesScreen extends StatefulWidget {
  const PublicacionesScreen({super.key});

  @override
  State<PublicacionesScreen> createState() => _PublicacionesScreenState();
}

class _PublicacionesScreenState extends State<PublicacionesScreen> {
  bool _inicializado = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_inicializado) {
      _inicializado = true;
      _inicializar();
    }
  }

  Future<void> _inicializar() async {
    final auth = context.read<AuthProvider>();
    final perfil = context.read<PerfilProvider>();
    final id = auth.usuario?['id'];
    if (id != null && perfil.juegos.isEmpty) {
      await perfil.cargarPerfil(id);
    }
    if (!mounted) return;
    await Future.wait([
      context.read<PublicacionesProvider>().buscar(),
      context.read<MatchesProvider>().cargarTodo(),
      context.read<AmistadProvider>().cargarTodo(),
      context.read<ChatProvider>().cargarConversaciones(),
    ]);
  }

  Future<void> _recargar() async {
    await context.read<PublicacionesProvider>().buscar();
  }

  Future<void> _abrirFiltros() async {
    final prov = context.read<PublicacionesProvider>();
    final perfil = context.read<PerfilProvider>();

    var tipoEtiqueta = PublicacionConstants.tiposFiltroEtiquetas.first;
    if (prov.filtroTipo != null && prov.filtroTipo!.isNotEmpty) {
      for (var i = 0; i < PublicacionConstants.tiposFiltroValores.length; i++) {
        if (PublicacionConstants.tiposFiltroValores[i] == prov.filtroTipo) {
          tipoEtiqueta = PublicacionConstants.tiposFiltroEtiquetas[i];
          break;
        }
      }
    }
    var paisEtiqueta = prov.filtroPais == null || prov.filtroPais!.isEmpty
        ? PaisUtil.todos
        : PaisUtil.codigoANombre(prov.filtroPais);
    var juegoEtiqueta = prov.filtroJuegoNombre ?? 'Todos los juegos';
    var ordenEtiqueta = prov.filtroOrden == PublicacionConstants.ordenReputacion
        ? 'Mayor reputación'
        : 'Más recientes';

    final juegosFiltro = [
      'Todos los juegos',
      ...perfil.juegos.map((j) => j['nombre']?.toString() ?? 'Juego'),
    ];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: SteamColors.bgPanel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Filtros',
                          style: TextStyle(
                            color: SteamColors.light,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close, color: SteamColors.muted),
                          tooltip: 'Cerrar',
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    DropField(
                      label: 'Tipo',
                      value: tipoEtiqueta,
                      items: PublicacionConstants.tiposFiltroEtiquetas,
                      onChanged: (v) => setSheetState(() => tipoEtiqueta = v),
                    ),
                    DropField(
                      label: 'País',
                      value: paisEtiqueta,
                      items: [PaisUtil.todos, ...PaisUtil.nombres],
                      onChanged: (v) => setSheetState(() => paisEtiqueta = v),
                    ),
                    DropField(
                      label: 'Juego',
                      value: juegoEtiqueta,
                      items: juegosFiltro,
                      onChanged: (v) => setSheetState(() => juegoEtiqueta = v),
                    ),
                    DropField(
                      label: 'Orden',
                      value: ordenEtiqueta,
                      items: const ['Más recientes', 'Mayor reputación'],
                      onChanged: (v) => setSheetState(() => ordenEtiqueta = v),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              Navigator.pop(context);
                              await prov.limpiarFiltros();
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: SteamColors.muted,
                              side: const BorderSide(color: SteamColors.border),
                            ),
                            child: const Text('Limpiar'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              final tipoVal =
                                  PublicacionConstants.valorTipoFiltro(tipoEtiqueta);
                              final paisVal = paisEtiqueta == PaisUtil.todos
                                  ? null
                                  : PaisUtil.nombreACodigo(paisEtiqueta);

                              int? appid;
                              String? juegoNombre;
                              if (juegoEtiqueta != 'Todos los juegos') {
                                for (final j in perfil.juegos) {
                                  if ((j['nombre']?.toString() ?? '') == juegoEtiqueta) {
                                    appid = j['appid'] as int?;
                                    juegoNombre = juegoEtiqueta;
                                    break;
                                  }
                                }
                              }

                              final orden = ordenEtiqueta == 'Mayor reputación'
                                  ? PublicacionConstants.ordenReputacion
                                  : PublicacionConstants.ordenRecientes;

                              Navigator.pop(context);
                              await prov.setFiltros(
                                tipo: tipoVal.isEmpty ? null : tipoVal,
                                pais: paisVal,
                                appid: appid,
                                juegoNombre: juegoNombre,
                                orden: orden,
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: SteamColors.blue,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Aplicar'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final publicacionesProv = context.watch<PublicacionesProvider>();
    final auth = context.watch<AuthProvider>();
    final matchesProv = context.watch<MatchesProvider>();
    final amistadProv = context.watch<AmistadProvider>();

    final feed = Column(
      children: [
        if (publicacionesProv.tieneFiltrosActivos)
          _FiltrosActivosBar(
            prov: publicacionesProv,
            onEditar: _abrirFiltros,
            onLimpiar: () => publicacionesProv.limpiarFiltros(),
          ),
        Expanded(
          child: RefreshIndicator(
            color: SteamColors.blue,
            backgroundColor: SteamColors.bgDeep,
            onRefresh: _recargar,
            child: _buildLista(
              publicacionesProv,
              auth,
              matchesProv,
              amistadProv,
              auth.usuario?['id'] as int?,
            ),
          ),
        ),
      ],
    );

    final esEscritorio = MediaQuery.of(context).size.width >= _kEscritorio;

    if (esEscritorio) {
      return Scaffold(
        backgroundColor: SteamColors.bgDeep,
        appBar: SteamAppBar(
          title: 'PUBLICACIONES',
          actions: [
            IconButton(
              icon: Icon(
                Icons.tune_rounded,
                color: publicacionesProv.tieneFiltrosActivos
                    ? SteamColors.blue
                    : SteamColors.muted,
              ),
              tooltip: 'Filtros',
              onPressed: _abrirFiltros,
            ),
            IconButton(
              icon: const Icon(Icons.refresh, color: SteamColors.blue),
              tooltip: 'Actualizar',
              onPressed: _recargar,
            ),
          ],
        ),
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 220,
              child: _AccesosRapidos(
                filtroActivo: publicacionesProv.filtroTipo,
                onFiltrar: (tipo) => publicacionesProv.setFiltros(tipo: tipo),
              ),
            ),
            const VerticalDivider(color: SteamColors.border, width: 1),
            Expanded(
              child: Column(
                children: [
                  _ComposerBar(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const CrearPublicacionScreen()),
                    ),
                  ),
                  Expanded(child: feed),
                ],
              ),
            ),
            const VerticalDivider(color: SteamColors.border, width: 1),
            const SizedBox(width: 260, child: _ChatsColumna()),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: SteamColors.bgDeep,
      appBar: SteamAppBar(
        title: 'PUBLICACIONES',
        actions: [
          IconButton(
            icon: Icon(
              Icons.tune_rounded,
              color: publicacionesProv.tieneFiltrosActivos
                  ? SteamColors.blue
                  : SteamColors.muted,
            ),
            tooltip: 'Filtros',
            onPressed: _abrirFiltros,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: SteamColors.blue),
            tooltip: 'Actualizar',
            onPressed: _recargar,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CrearPublicacionScreen()),
          );
        },
        backgroundColor: SteamColors.blue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text(
          'Crear',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: DesktopBodyWidth(child: SafeArea(child: feed)),
    );
  }

  Widget _buildLista(
    PublicacionesProvider publicacionesProv,
    AuthProvider auth,
    MatchesProvider matchesProv,
    AmistadProvider amistadProv,
    int? miId,
  ) {
    if (publicacionesProv.cargando) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation(SteamColors.blue),
        ),
      );
    }

    if (publicacionesProv.error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            publicacionesProv.error!,
            style: const TextStyle(color: Colors.red),
          ),
        ],
      );
    }

    if (publicacionesProv.publicaciones.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 40),
          Center(
            child: Text(
              publicacionesProv.tieneFiltrosActivos
                  ? 'No hay publicaciones con estos filtros.'
                  : 'No hay publicaciones disponibles.',
              style: const TextStyle(color: SteamColors.textSec),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
      itemCount: publicacionesProv.publicaciones.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final publicacion = publicacionesProv.publicaciones[index];
        final autorId = publicacion['id_usu'] as int?;
        final esMia = miId != null && miId == autorId;
        final relacion = RelacionResumen.paraUsuario(
          miId: miId,
          otroId: autorId,
          matches: matchesProv,
          amistad: amistadProv,
        );

        return PublicacionCard(
          publicacion: Map<String, dynamic>.from(publicacion as Map),
          esMia: esMia,
          relacion: relacion,
          onTap: () async {
            final id = publicacion['id_publi'] as int?;
            if (id == null) return;
            final actualizado = await Navigator.of(context).push<bool>(
              MaterialPageRoute(
                builder: (_) => PublicacionDetalleScreen(idPubli: id),
              ),
            );
            if (actualizado == true && context.mounted) {
              await _recargar();
            }
          },
          onTapAutor: autorId != null
              ? () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => UsuarioDetalleScreen(
                        userId: autorId,
                        idPubli: publicacion['id_publi'] as int?,
                        tituloPublicacion: publicacion['titulo_publi'] as String?,
                      ),
                    ),
                  );
                }
              : null,
          onCerrar: esMia
              ? () async {
                  await publicacionesProv.cerrar(publicacion['id_publi']);
                  if (!context.mounted) return;
                  if (publicacionesProv.error != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(publicacionesProv.error!)),
                    );
                  }
                }
              : null,
        );
      },
    );
  }
}

class _FiltrosActivosBar extends StatelessWidget {
  final PublicacionesProvider prov;
  final VoidCallback onEditar;
  final VoidCallback onLimpiar;

  const _FiltrosActivosBar({
    required this.prov,
    required this.onEditar,
    required this.onLimpiar,
  });

  @override
  Widget build(BuildContext context) {
    final chips = <String>[];
    if (prov.filtroTipo != null && prov.filtroTipo!.isNotEmpty) {
      chips.add(PublicacionConstants.etiquetaTipo(prov.filtroTipo));
    }
    if (prov.filtroPais != null && prov.filtroPais!.isNotEmpty) {
      chips.add(PaisUtil.codigoANombre(prov.filtroPais));
    }
    if (prov.filtroJuegoNombre != null) {
      chips.add(prov.filtroJuegoNombre!);
    }
    if (prov.filtroOrden == PublicacionConstants.ordenReputacion) {
      chips.add('Por reputación');
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: SteamColors.bgPanel,
        border: Border(bottom: BorderSide(color: SteamColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: chips
                    .map(
                      (c) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Chip(
                          label: Text(c, style: const TextStyle(fontSize: 11)),
                          backgroundColor: SteamColors.bgCard,
                          labelStyle: const TextStyle(color: SteamColors.blue),
                          side: const BorderSide(color: SteamColors.border),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
          TextButton(onPressed: onEditar, child: const Text('Editar')),
          IconButton(
            icon: const Icon(Icons.clear, size: 18, color: SteamColors.muted),
            tooltip: 'Quitar filtros',
            onPressed: onLimpiar,
          ),
        ],
      ),
    );
  }
}

/// Barra de composición inline sobre el feed (lenguaje visual del
/// wireframe: "Comparte algo..." + botón Publicar, en vez de un FAB
/// flotante). Abre el mismo formulario de creación de siempre.
class _ComposerBar extends StatelessWidget {
  final VoidCallback onTap;

  const _ComposerBar({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: SteamColors.bgCard,
        borderRadius: BorderRadius.circular(SteamRadii.sm),
        border: Border.all(color: SteamColors.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(SteamRadii.sm),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Comparte algo con la comunidad...',
                    style: TextStyle(color: SteamColors.textSec, fontSize: 13.5),
                  ),
                ),
                const Icon(Icons.image_outlined, size: 18, color: SteamColors.muted),
                const SizedBox(width: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: SteamColors.blue,
                    borderRadius: BorderRadius.circular(SteamRadii.sm),
                  ),
                  child: const Text(
                    'Publicar',
                    style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700),
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

/// Columna izquierda de escritorio (posición del wireframe): accesos a
/// solicitudes/matches y atajos de filtro por tipo, sobre el feed real de
/// publicaciones — nada inventado, todo enlaza a funcionalidad que ya existe.
class _AccesosRapidos extends StatelessWidget {
  final String? filtroActivo;
  final ValueChanged<String?> onFiltrar;

  const _AccesosRapidos({required this.filtroActivo, required this.onFiltrar});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'ACCESOS RÁPIDOS',
              style: TextStyle(
                color: SteamColors.textSec,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(height: 8),
          _AccesoItem(
            icon: Icons.inbox_outlined,
            label: 'Mis solicitudes',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MatchesScreen()),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Text(
              'FILTRAR POR TIPO',
              style: TextStyle(
                color: SteamColors.textSec,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
          ),
          _AccesoItem(
            icon: Icons.apps_rounded,
            label: 'Todos los tipos',
            activo: filtroActivo == null || filtroActivo!.isEmpty,
            onTap: () => onFiltrar(null),
          ),
          for (var i = 1; i < PublicacionConstants.tiposFiltroValores.length; i++)
            _AccesoItem(
              icon: Icons.label_outline,
              label: PublicacionConstants.tiposFiltroEtiquetas[i],
              activo: filtroActivo == PublicacionConstants.tiposFiltroValores[i],
              onTap: () => onFiltrar(PublicacionConstants.tiposFiltroValores[i]),
            ),
        ],
      ),
    );
  }
}

class _AccesoItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool activo;
  final VoidCallback onTap;

  const _AccesoItem({
    required this.icon,
    required this.label,
    this.activo = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: activo ? SteamColors.bgCard : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(icon, size: 18, color: activo ? SteamColors.blue : SteamColors.muted),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: activo ? SteamColors.blue : SteamColors.light,
                    fontSize: 13,
                    fontWeight: activo ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Columna derecha de escritorio (posición del wireframe): lista de chats.
/// El panel de chat flotante (ver FloatingChat) cubre la conversación en sí;
/// esta columna es solo el acceso rápido, igual que en el wireframe.
class _ChatsColumna extends StatelessWidget {
  const _ChatsColumna();

  @override
  Widget build(BuildContext context) {
    final chatProv = context.watch<ChatProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'CHATS',
            style: TextStyle(
              color: SteamColors.textSec,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
        ),
        if (chatProv.cargandoLista && chatProv.conversaciones.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(SteamColors.blue),
              ),
            ),
          )
        else if (chatProv.conversaciones.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'No tienes conversaciones aún.',
              style: TextStyle(color: SteamColors.textSec, fontSize: 12),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              itemCount: chatProv.conversaciones.length,
              itemBuilder: (context, index) {
                final chat = Map<String, dynamic>.from(
                  chatProv.conversaciones[index] as Map,
                );
                final nombre = ChatProvider.nombreOtro(chat);
                final idChat = chat['id_chat'];
                final inicial = nombre.isNotEmpty ? nombre[0].toUpperCase() : '?';

                return ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: SteamColors.blue.withValues(alpha: 0.2),
                    child: Text(
                      inicial,
                      style: const TextStyle(color: SteamColors.blue, fontWeight: FontWeight.w800, fontSize: 12),
                    ),
                  ),
                  title: Text(
                    nombre,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: SteamColors.light, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  onTap: idChat == null
                      ? null
                      : () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ChatConversationScreen(
                                chatId: idChat is int ? idChat : int.parse(idChat.toString()),
                                otroNombre: nombre,
                                otroUserId: ChatProvider.otroUserId(chat),
                              ),
                            ),
                          );
                        },
                );
              },
            ),
          ),
      ],
    );
  }
}

