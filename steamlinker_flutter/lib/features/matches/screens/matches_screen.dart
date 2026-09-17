import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../theme/colors.dart';
import '../../../theme/radii.dart';
import '../../../widgets/calificar_dialog.dart';
import '../../../widgets/desktop_body_width.dart';
import '../../../widgets/steam_app_bar.dart';
import '../../../widgets/steam_toast.dart';
import '../../auth/providers/auth_provider.dart';
import '../../calificaciones/providers/calificaciones_provider.dart';
import '../../notifications/providers/notificaciones_provider.dart';
import '../../usuarios/screens/usuario_detalle_screen.dart';
import '../providers/matches_provider.dart';

class MatchesScreen extends StatefulWidget {
  const MatchesScreen({super.key});

  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen> {
  bool _inicializado = false;
  int _tabActual = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_inicializado) {
      _inicializado = true;
      context.read<MatchesProvider>().cargarTodo();
    }
  }

  int? _otroUsuarioId(Map<String, dynamic> item, int miId) {
    if (item['id_solicitante'] == miId) return item['id_receptor'] as int?;
    return item['id_solicitante'] as int?;
  }

  String _nombreOtro(Map<String, dynamic> item, int miId, {required bool recibido}) {
    if (recibido) return item['solicitante_username'] ?? 'Usuario';
    return item['receptor_username'] ?? 'Usuario';
  }

  Future<void> _calificar(Map<String, dynamic> item, int miId) async {
    final idCalificado = _otroUsuarioId(item, miId);
    if (idCalificado == null) return;
    final nombre = _nombreOtro(item, miId, recibido: _tabActual == 0);

    final resultado = await mostrarCalificarDialog(
      context,
      nombreUsuario: nombre,
    );
    if (resultado == null || !mounted) return;

    final exito = await context.read<CalificacionesProvider>().crear(
      idMatch: item['id_match'] as int,
      idCalificado: idCalificado,
      estrellas: resultado.estrellas,
      confiable: resultado.confiable,
      comentario: resultado.comentario,
    );

    if (!mounted) return;
    if (exito) {
      showSteamToast(context, 'Calificación enviada', SteamColors.green);
    } else {
      showSteamToast(
        context,
        context.read<CalificacionesProvider>().error ?? 'Error al calificar',
        Colors.red,
      );
    }
  }

  void _abrirPerfil(int userId) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => UsuarioDetalleScreen(userId: userId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final matchesProv = context.watch<MatchesProvider>();
    final miId = context.watch<AuthProvider>().usuario?['id'];

    return Scaffold(
      backgroundColor: SteamColors.bgDeep,
      appBar: SteamAppBar(
        title: 'SOLICITUDES',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: SteamColors.blue),
            tooltip: 'Actualizar',
            onPressed: () => matchesProv.cargarTodo(),
          ),
        ],
      ),
      body: DesktopBodyWidth(child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  _TabButton(
                    label: 'Recibidos',
                    selected: _tabActual == 0,
                    onTap: () => setState(() => _tabActual = 0),
                  ),
                  const SizedBox(width: 12),
                  _TabButton(
                    label: 'Enviados',
                    selected: _tabActual == 1,
                    onTap: () => setState(() => _tabActual = 1),
                  ),
                ],
              ),
            ),
            Expanded(
              child: matchesProv.cargando
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation(SteamColors.blue),
                      ),
                    )
                  : _tabActual == 0
                      ? _buildLista(matchesProv.recibidos, matchesProv, miId, recibido: true)
                      : _buildLista(matchesProv.enviados, matchesProv, miId, recibido: false),
            ),
          ],
        ),
      )),
    );
  }

  Widget _buildLista(
    List<dynamic> items,
    MatchesProvider prov,
    int? miId, {
    required bool recibido,
  }) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          recibido
              ? 'No tienes solicitudes recibidas.'
              : 'No tienes solicitudes enviadas.',
          style: const TextStyle(color: SteamColors.textSec),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = Map<String, dynamic>.from(items[index] as Map);
        final estado = item['estado_match'] ?? 'Pendiente';
        final otroId = miId != null ? _otroUsuarioId(item, miId) : null;
        final nombre = miId != null
            ? _nombreOtro(item, miId, recibido: recibido)
            : 'Usuario';
        final pais = recibido
            ? item['solicitante_pais']
            : item['receptor_pais'];
        final repu = recibido
            ? item['solicitante_reputacion']
            : item['receptor_reputacion'];

        return _MatchCard(
          title: nombre,
          subtitle: 'País: ${pais ?? 'N/A'} • Repu: ${repu ?? 0}',
          estado: estado,
          onTap: otroId != null ? () => _abrirPerfil(otroId) : null,
          onAccept: estado == 'Pendiente' && recibido
              ? () async {
                  await prov.responder(item['id_match'], 'Aceptada');
                  if (!context.mounted) return;
                  context.read<NotificacionesProvider>().cargarContador();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Solicitud aceptada — chat creado')),
                  );
                }
              : null,
          onReject: estado == 'Pendiente' && recibido
              ? () async {
                  await prov.responder(item['id_match'], 'Rechazada');
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Solicitud rechazada')),
                  );
                }
              : null,
          onCalificar: estado == 'Aceptada' && miId != null
              ? () => _calificar(item, miId)
              : null,
        );
      },
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TabButton({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? SteamColors.blue : SteamColors.bgPanel,
            borderRadius: BorderRadius.circular(SteamRadii.sm),
            border: Border.all(color: selected ? SteamColors.blue : SteamColors.border),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.white : SteamColors.light,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String estado;
  final VoidCallback? onTap;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;
  final VoidCallback? onCalificar;

  const _MatchCard({
    required this.title,
    required this.subtitle,
    required this.estado,
    this.onTap,
    this.onAccept,
    this.onReject,
    this.onCalificar,
  });

  Color get _estadoColor {
    switch (estado) {
      case 'Aceptada':
        return SteamColors.green;
      case 'Rechazada':
        return SteamColors.red;
      default:
        return SteamColors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SteamColors.bgPanel,
      borderRadius: BorderRadius.circular(SteamRadii.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(SteamRadii.sm),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(SteamRadii.sm),
            border: Border.all(color: SteamColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: SteamColors.light,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _estadoColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(SteamRadii.sm),
                    ),
                    child: Text(
                      estado,
                      style: TextStyle(
                        color: _estadoColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(subtitle, style: const TextStyle(color: SteamColors.textSec, fontSize: 13)),
              if (onAccept != null || onReject != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: SteamColors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SteamRadii.sm)),
                        ),
                        onPressed: onAccept,
                        child: const Text('Aceptar'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: SteamColors.red),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SteamRadii.sm)),
                        ),
                        onPressed: onReject,
                        child: const Text('Rechazar', style: TextStyle(color: SteamColors.red)),
                      ),
                    ),
                  ],
                ),
              ],
              if (onCalificar != null) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: SteamColors.blue,
                      side: const BorderSide(color: SteamColors.blue),
                    ),
                    onPressed: onCalificar,
                    icon: const Icon(Icons.star_outline, size: 18),
                    label: const Text('Calificar'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
