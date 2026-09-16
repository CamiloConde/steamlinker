import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../theme/colors.dart';
import '../../../theme/radii.dart';
import '../../../widgets/steam_app_bar.dart';
import '../providers/calificaciones_provider.dart';

class ResenasUsuarioScreen extends StatefulWidget {
  final int userId;
  final String username;

  const ResenasUsuarioScreen({
    super.key,
    required this.userId,
    required this.username,
  });

  @override
  State<ResenasUsuarioScreen> createState() => _ResenasUsuarioScreenState();
}

class _ResenasUsuarioScreenState extends State<ResenasUsuarioScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CalificacionesProvider>().cargarDeUsuario(widget.userId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<CalificacionesProvider>();

    return Scaffold(
      backgroundColor: SteamColors.bgDeep,
      appBar: SteamAppBar(title: 'RESEÑAS'),
      body: prov.cargandoResenas
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(SteamColors.blue),
              ),
            )
          : prov.errorResenas != null
              ? Center(
                  child: Text(
                    prov.errorResenas!,
                    style: const TextStyle(color: SteamColors.light),
                  ),
                )
              : RefreshIndicator(
                  color: SteamColors.blue,
                  onRefresh: () =>
                      context.read<CalificacionesProvider>().cargarDeUsuario(widget.userId),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      _ResumenCard(
                        username: widget.username,
                        promedio: prov.promedioResenas,
                        total: prov.totalResenas,
                      ),
                      const SizedBox(height: 16),
                      if (prov.resenas.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Aún no tiene reseñas públicas.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: SteamColors.textSec),
                          ),
                        )
                      else
                        ...prov.resenas.map((r) => _ResenaTile(resena: Map<String, dynamic>.from(r as Map))),
                    ],
                  ),
                ),
    );
  }
}

class _ResumenCard extends StatelessWidget {
  final String username;
  final double promedio;
  final int total;

  const _ResumenCard({
    required this.username,
    required this.promedio,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SteamColors.bgPanel,
        borderRadius: BorderRadius.circular(SteamRadii.sm),
        border: Border.all(color: SteamColors.border),
      ),
      child: Column(
        children: [
          Text(
            username,
            style: const TextStyle(
              color: SteamColors.light,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '★ ${promedio.toStringAsFixed(1)}',
            style: const TextStyle(
              color: SteamColors.green,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            '$total reseña${total == 1 ? '' : 's'}',
            style: const TextStyle(color: SteamColors.textSec, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _ResenaTile extends StatelessWidget {
  final Map<String, dynamic> resena;

  const _ResenaTile({required this.resena});

  @override
  Widget build(BuildContext context) {
    final estrellas = resena['estrellas_cali'];
    final confiable = resena['confiable_cali'];
    final comentario = resena['comentario_cali']?.toString() ?? '';
    final autor = resena['calificador_username'] ?? 'Usuario';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SteamColors.bgPanel,
        borderRadius: BorderRadius.circular(SteamRadii.sm),
        border: Border.all(color: SteamColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                autor,
                style: const TextStyle(
                  color: SteamColors.light,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              Text(
                '★ ${estrellas?.toString() ?? '—'}',
                style: const TextStyle(color: SteamColors.yellow, fontSize: 13),
              ),
            ],
          ),
          if (confiable != null) ...[
            const SizedBox(height: 6),
            Text(
              confiable == true ? 'Marcado como confiable' : 'No marcado como confiable',
              style: TextStyle(
                color: confiable == true ? SteamColors.green : SteamColors.muted,
                fontSize: 11,
              ),
            ),
          ],
          if (comentario.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              comentario,
              style: const TextStyle(color: SteamColors.textSec, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}
