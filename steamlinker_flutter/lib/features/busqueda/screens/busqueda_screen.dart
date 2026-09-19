import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../theme/colors.dart';
import '../../../theme/radii.dart';
import '../../../widgets/steam_app_bar.dart';
import '../../../widgets/steam_card.dart';
import '../../../widgets/steam_buttons.dart';
import '../../../widgets/steam_toast.dart';
import '../../perfil/providers/perfil_provider.dart';

class BusquedaScreen extends StatefulWidget {
  const BusquedaScreen({super.key});

  @override
  State<BusquedaScreen> createState() => _BusquedaScreenState();
}

class _BusquedaScreenState extends State<BusquedaScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _buscandoJuegos = false;
  List<dynamic> _resultados = [];
  String? _errorBusqueda;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _buscarJuegos(String query) async {
    if (query.trim().isEmpty) {
      if (!mounted) return;
      setState(() {
        _resultados = [];
        _errorBusqueda = null;
      });
      return;
    }

    setState(() {
      _buscandoJuegos = true;
      _errorBusqueda = null;
    });

    final perfilProv = context.read<PerfilProvider>();
    final resultados = await perfilProv.buscarJuegos(query.trim());
    if (!mounted) return;

    setState(() {
      _resultados = resultados;
      _buscandoJuegos = false;
      if (resultados.isEmpty) {
        _errorBusqueda = 'No se encontraron juegos para "$query"';
      }
    });
  }

  Future<void> _agregarJuego(Map<String, dynamic> juego) async {
    final perfilProv = context.read<PerfilProvider>();
    final exito = await perfilProv.agregarJuego({
      'appid': juego['appid'],
      'nombre': juego['nombre'],
      'headerimg': juego['headerimg'],
      'capsuleimg': juego['capsuleimg'],
      'horas': 0,
      'favorito': false,
    });

    if (!mounted) return;
    if (exito) {
      showSteamToast(context, 'Juego agregado al perfil', SteamColors.green);
      setState(() {
        _resultados = [];
        _searchController.clear();
      });
    } else {
      showSteamToast(
        context,
        perfilProv.error ?? 'No fue posible agregar el juego',
        Colors.red,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final perfilProv = context.watch<PerfilProvider>();

    return Scaffold(
      backgroundColor: SteamColors.bgDeep,
      appBar: const SteamAppBar(title: 'BUSCAR JUEGOS'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: SteamCard(
          icon: Icons.search,
          title: 'Buscar juegos en Steam',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _searchController,
                style: const TextStyle(color: SteamColors.light),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Nombre del juego',
                  hintText: 'Buscar en Steam',
                  filled: true,
                  fillColor: SteamColors.bgInput,
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.search,
                          color: SteamColors.muted,
                        ),
                        tooltip: 'Buscar',
                        onPressed: () => _buscarJuegos(_searchController.text),
                      ),
                      if (_searchController.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(
                            Icons.clear,
                            color: SteamColors.muted,
                          ),
                          tooltip: 'Limpiar',
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _resultados = [];
                              _errorBusqueda = null;
                            });
                          },
                        ),
                    ],
                  ),
                ),
                textInputAction: TextInputAction.search,
                onSubmitted: _buscarJuegos,
              ),
              const SizedBox(height: 16),
              if (_buscandoJuegos)
                const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation(SteamColors.blue),
                  ),
                )
              else if (_errorBusqueda != null)
                Text(
                  _errorBusqueda!,
                  style: const TextStyle(color: SteamColors.textSec),
                )
              else if (_resultados.isEmpty)
                const Text(
                  'Escribe el nombre de un juego y presiona Enter para buscarlo.',
                  style: TextStyle(color: SteamColors.textSec, fontSize: 12),
                )
              else
                Column(
                  children: _resultados.map((juego) {
                    final yaAgregado = perfilProv.juegos.any(
                      (j) => j['appid'].toString() == juego['appid'].toString(),
                    );
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Semantics(
                        image: true,
                        label: 'Carátula de ${juego['nombre'] ?? 'juego'}',
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(SteamRadii.sm),
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
                      ),
                      title: Text(
                        juego['nombre'] ?? 'Juego',
                        style: const TextStyle(color: SteamColors.light),
                      ),
                      subtitle: Text(
                        yaAgregado
                            ? 'Ya agregado a tu biblioteca'
                            : 'AppID: ${juego['appid']}',
                        style: const TextStyle(
                          color: SteamColors.textSec,
                          fontSize: 12,
                        ),
                      ),
                      trailing: yaAgregado
                          ? const SteamButtonOutline(
                              label: 'Agregado',
                              fullWidth: false,
                              compact: true,
                              onTap: null,
                            )
                          : SteamButtonPrimary(
                              label: 'Agregar',
                              icon: Icons.add,
                              fullWidth: false,
                              compact: true,
                              onTap: (ctx) => _agregarJuego(juego),
                            ),
                    );
                  }).toList(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
