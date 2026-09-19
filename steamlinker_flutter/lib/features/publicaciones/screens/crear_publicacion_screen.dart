import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/pais_util.dart';
import '../../../core/constants/publicacion_constants.dart';
import '../../../theme/colors.dart';
import '../../../widgets/drop_field.dart';
import '../../../widgets/pais_selector_field.dart';
import '../../../widgets/steam_app_bar.dart';
import '../../../widgets/steam_buttons.dart';
import '../../../widgets/steam_card.dart';
import '../../../widgets/steam_toast.dart';
import '../../auth/providers/auth_provider.dart';
import '../../perfil/providers/perfil_provider.dart';
import '../providers/publicaciones_provider.dart';

class CrearPublicacionScreen extends StatefulWidget {
  /// Si se pasa, la pantalla entra en modo edición: precarga los campos
  /// y guarda con PUT /editar en vez de crear una publicación nueva.
  /// Antes no existía ninguna forma de corregir una publicación ya
  /// creada -- pedido explícito del usuario.
  final Map<String, dynamic>? publicacionExistente;

  const CrearPublicacionScreen({super.key, this.publicacionExistente});

  @override
  State<CrearPublicacionScreen> createState() => _CrearPublicacionScreenState();
}

class _CrearPublicacionScreenState extends State<CrearPublicacionScreen> {
  final _tituloController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _busquedaController = TextEditingController();
  final _cuposController = TextEditingController();

  String _tipoEtiqueta = PublicacionConstants.tiposCrearEtiquetas.first;
  String _paisEtiqueta = PaisUtil.todos;
  final List<Map<String, dynamic>> _juegosSeleccionados = [];
  bool _guardando = false;
  bool _buscandoSteam = false;
  List<dynamic> _resultadosSteam = [];

  bool get _editando => widget.publicacionExistente != null;

  bool get _requiereSteam =>
      PublicacionConstants.requiereSteam(PublicacionConstants.valorTipoCrear(_tipoEtiqueta));

  // Para publicaciones que exigen Steam vinculado (familia/miembros) solo
  // se puede ofrecer lo que Steam confirma que sí tienes -- si no, la
  // "verificación" no significaría nada. Prueba pedida por el usuario.
  List<dynamic> _bibliotecaMostrada(PerfilProvider perfilProv) {
    if (!_requiereSteam) return perfilProv.juegos;
    return perfilProv.juegos.where((j) => j['origen'] == 'steam').toList();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargarBiblioteca());

    final pub = widget.publicacionExistente;
    if (pub != null) {
      _tituloController.text = (pub['titulo_publi'] as String?) ?? '';
      _descripcionController.text = (pub['descrip_publi'] as String?) ?? '';
      final cupos = pub['cupos_totales'];
      if (cupos != null) _cuposController.text = '$cupos';
      final tipo = pub['tipo_publi'] as String?;
      if (tipo != null && PublicacionConstants.tipoEtiquetas.containsKey(tipo)) {
        _tipoEtiqueta = PublicacionConstants.tipoEtiquetas[tipo]!;
      }
      final paisCodigo = pub['paisfiltro_publi'] as String?;
      if (paisCodigo != null && paisCodigo.isNotEmpty) {
        _paisEtiqueta = PaisUtil.codigoANombre(paisCodigo);
      }
      final juegos = pub['juegos'] as List<dynamic>?;
      if (juegos != null) {
        for (final j in juegos) {
          final map = Map<String, dynamic>.from(j as Map);
          _juegosSeleccionados.add({
            'appid': map['appid'],
            'nombre': map['nombre'] ?? map['nom_jg'] ?? '',
            'headerimg': map['headerimg'] ?? map['headerimg_jg'] ?? '',
            'capsuleimg': map['capsuleimg'] ?? map['capsuleimg_jg'] ?? '',
          });
        }
      }
    }
  }

  Future<void> _cargarBiblioteca() async {
    final auth = context.read<AuthProvider>();
    final perfil = context.read<PerfilProvider>();
    final id = auth.usuario?['id'];
    if (id == null) return;
    if (perfil.juegos.isEmpty) {
      await perfil.cargarPerfil(id);
    }
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _descripcionController.dispose();
    _busquedaController.dispose();
    _cuposController.dispose();
    super.dispose();
  }

  bool _estaSeleccionado(int appid) =>
      _juegosSeleccionados.any((j) => j['appid'] == appid);

  void _toggleJuego(Map<String, dynamic> juego) {
    final appid = juego['appid'];
    setState(() {
      if (_estaSeleccionado(appid)) {
        _juegosSeleccionados.removeWhere((j) => j['appid'] == appid);
      } else {
        _juegosSeleccionados.add({
          'appid': appid,
          'nombre': juego['nombre'] ?? juego['nom_jg'] ?? '',
          'headerimg': juego['headerimg'] ?? juego['headerimg_jg'] ?? '',
          'capsuleimg': juego['capsuleimg'] ?? juego['capsuleimg_jg'] ?? '',
        });
      }
    });
  }

  // Pedido explícito del usuario: marcar uno por uno era tedioso, sobre
  // todo para quien busca miembros/familia y quiere ofrecer toda su
  // biblioteca verificada.
  void _marcarTodosVerificados(List<dynamic> juegos) {
    setState(() {
      final todosMarcados = juegos.every((j) => _estaSeleccionado(j['appid']));
      if (todosMarcados) {
        for (final j in juegos) {
          _juegosSeleccionados.removeWhere((s) => s['appid'] == j['appid']);
        }
      } else {
        for (final j in juegos) {
          if (!_estaSeleccionado(j['appid'])) {
            _juegosSeleccionados.add({
              'appid': j['appid'],
              'nombre': j['nombre'] ?? j['nom_jg'] ?? '',
              'headerimg': j['headerimg'] ?? j['headerimg_jg'] ?? '',
              'capsuleimg': j['capsuleimg'] ?? j['capsuleimg_jg'] ?? '',
            });
          }
        }
      }
    });
  }

  Future<void> _buscarEnSteam() async {
    final query = _busquedaController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _buscandoSteam = true;
      _resultadosSteam = [];
    });

    final resultados = await context.read<PerfilProvider>().buscarJuegos(query);
    if (!mounted) return;
    setState(() {
      _resultadosSteam = resultados;
      _buscandoSteam = false;
    });
  }

  Future<void> _publicar() async {
    final titulo = _tituloController.text.trim();
    if (titulo.isEmpty) {
      showSteamToast(context, 'El título es obligatorio', Colors.red);
      return;
    }

    setState(() => _guardando = true);

    final pais = _paisEtiqueta == PaisUtil.todos
        ? null
        : PaisUtil.nombreACodigo(_paisEtiqueta);

    final tipo = PublicacionConstants.valorTipoCrear(_tipoEtiqueta);
    final cuposTexto = _cuposController.text.trim();
    final cuposTotales = tipo != 'otro' && cuposTexto.isNotEmpty
        ? int.tryParse(cuposTexto)
        : null;
    final descripcion = _descripcionController.text.trim().isEmpty
        ? null
        : _descripcionController.text.trim();

    final prov = context.read<PublicacionesProvider>();
    final exito = _editando
        ? await prov.editar(
            id: widget.publicacionExistente!['id_publi'] as int,
            titulo: titulo,
            descripcion: descripcion,
            pais: pais,
            cuposTotales: cuposTotales,
            juegos: _juegosSeleccionados,
          )
        : await prov.crear(
            tipo: tipo,
            titulo: titulo,
            descripcion: descripcion,
            pais: pais,
            cuposTotales: cuposTotales,
            juegos: _juegosSeleccionados,
          );

    if (!mounted) return;
    setState(() => _guardando = false);

    if (exito) {
      showSteamToast(
        context,
        _editando ? 'Publicación actualizada' : 'Publicación creada',
        SteamColors.green,
      );
      Navigator.of(context).pop();
    } else {
      final error = context.read<PublicacionesProvider>().error;
      showSteamToast(
        context,
        error ?? (_editando ? 'No se pudo editar' : 'No se pudo crear'),
        Colors.red,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final perfilProv = context.watch<PerfilProvider>();

    return Scaffold(
      backgroundColor: SteamColors.bgDeep,
      appBar: SteamAppBar(title: _editando ? 'EDITAR PUBLICACIÓN' : 'NUEVA PUBLICACIÓN'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SteamCard(
            icon: Icons.campaign_outlined,
            title: 'Detalles',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // El tipo no se puede editar -- cambiar de tipo tiene
                // efectos secundarios (requiere Steam, cupos por
                // defecto) que no aplican a medio camino. Se deshabilita
                // pasando onChanged null (DropdownButton ya lo pinta
                // como inactivo solo con eso).
                DropField(
                  label: 'Tipo',
                  value: _tipoEtiqueta,
                  items: PublicacionConstants.tiposCrearEtiquetas,
                  onChanged: _editando ? null : (v) => setState(() => _tipoEtiqueta = v),
                ),
                if (PublicacionConstants.requiereSteam(
                  PublicacionConstants.valorTipoCrear(_tipoEtiqueta),
                ))
                  const Padding(
                    padding: EdgeInsets.only(top: 4, bottom: 8),
                    child: Text(
                      'Necesitas tu cuenta de Steam vinculada para publicar esto.',
                      style: TextStyle(color: SteamColors.textSec, fontSize: 11),
                    ),
                  ),
                if (PublicacionConstants.valorTipoCrear(_tipoEtiqueta) != 'otro') ...[
                  const SizedBox(height: 4),
                  TextField(
                    controller: _cuposController,
                    keyboardType: TextInputType.number,
                    // keyboardType solo cambia el teclado en pantalla en
                    // móvil -- en web/escritorio con teclado físico no
                    // impide escribir letras. inputFormatters sí lo
                    // bloquea de verdad. El usuario lo notó probando.
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(color: SteamColors.light),
                    decoration: const InputDecoration(
                      labelText: 'Cupos buscados (opcional)',
                      helperText: 'Si lo dejas vacío, la publicación no mostrará límite de cupos.',
                      filled: true,
                      fillColor: SteamColors.bgInput,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: _tituloController,
                  style: const TextStyle(color: SteamColors.light),
                  decoration: const InputDecoration(
                    labelText: 'Título',
                    hintText: 'Ej. Busco familia para Elden Ring',
                    filled: true,
                    fillColor: SteamColors.bgInput,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _descripcionController,
                  maxLines: 4,
                  style: const TextStyle(color: SteamColors.light),
                  decoration: const InputDecoration(
                    labelText: 'Descripción (opcional)',
                    filled: true,
                    fillColor: SteamColors.bgInput,
                  ),
                ),
                const SizedBox(height: 4),
                PaisSelectorField(
                  label: 'País objetivo (opcional)',
                  value: _paisEtiqueta,
                  items: [PaisUtil.todos, ...PaisUtil.nombres],
                  onChanged: (v) => setState(() => _paisEtiqueta = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SteamCard(
            icon: Icons.videogame_asset_outlined,
            title: 'Juegos (${_juegosSeleccionados.length})',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_juegosSeleccionados.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _juegosSeleccionados.map((j) {
                      return InputChip(
                        label: Text(
                          j['nombre'] ?? 'Juego',
                          style: const TextStyle(color: SteamColors.light),
                        ),
                        deleteIconColor: SteamColors.muted,
                        backgroundColor: SteamColors.bgPanel,
                        onDeleted: () => _toggleJuego(j),
                      );
                    }).toList(),
                  ),
                if (_juegosSeleccionados.isNotEmpty) const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        _requiereSteam ? 'Juegos verificados' : 'Tu biblioteca',
                        style: const TextStyle(
                          color: SteamColors.textSec,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    if (_bibliotecaMostrada(perfilProv).isNotEmpty)
                      TextButton(
                        onPressed: () => _marcarTodosVerificados(_bibliotecaMostrada(perfilProv)),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          _bibliotecaMostrada(perfilProv)
                                  .every((j) => _estaSeleccionado(j['appid']))
                              ? 'Desmarcar todos'
                              : 'Marcar todos',
                          style: const TextStyle(
                            color: SteamColors.blue,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _requiereSteam
                        ? 'Son los juegos que Steam confirma que sí tienes en tu cuenta '
                            '(no los que agregaste a mano). Por eso solo estos se pueden ofrecer '
                            'aquí -- le dan confianza real a quien te contacte.'
                        : 'Elige los juegos de tu biblioteca que quieres mostrar en la publicación.',
                    style: const TextStyle(color: SteamColors.textSec, fontSize: 11),
                  ),
                ),
                if (perfilProv.cargando && perfilProv.juegos.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation(SteamColors.blue),
                      ),
                    ),
                  )
                else if (_bibliotecaMostrada(perfilProv).isEmpty)
                  Text(
                    _requiereSteam
                        ? 'No tienes juegos verificados por Steam todavía.'
                        : 'Agrega juegos a tu perfil para asociarlos a la publicación.',
                    style: const TextStyle(color: SteamColors.textSec, fontSize: 12),
                  )
                else
                  ..._bibliotecaMostrada(perfilProv).map((juego) {
                    final seleccionado = _estaSeleccionado(juego['appid']);
                    return CheckboxListTile(
                      value: seleccionado,
                      onChanged: (_) => _toggleJuego(juego),
                      activeColor: SteamColors.blue,
                      title: Text(
                        juego['nombre'] ?? 'Juego',
                        style: const TextStyle(color: SteamColors.light, fontSize: 13),
                      ),
                      subtitle: Text(
                        '${juego['horas'] ?? 0} h jugadas',
                        style: const TextStyle(color: SteamColors.textSec, fontSize: 11),
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    );
                  }),
                const Divider(color: SteamColors.border, height: 24),
                Text(
                  _requiereSteam ? 'Juegos que buscas' : 'Buscar en Steam',
                  style: const TextStyle(
                    color: SteamColors.textSec,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
                // El usuario aclaró el caso real: buscando miembros/familia
                // muchas veces el punto es justo pedir un juego que TÚ no
                // tienes (ej. "busco a alguien con Baldur's Gate 3"), no
                // solo ofrecer tu biblioteca verificada -- por eso este
                // buscador libre se mantiene para todos los tipos.
                if (_requiereSteam)
                  const Padding(
                    padding: EdgeInsets.only(top: 4, bottom: 8),
                    child: Text(
                      'Aunque no los tengas -- sirve para indicar qué juegos buscas en quien te contacte.',
                      style: TextStyle(color: SteamColors.textSec, fontSize: 11),
                    ),
                  ),
                const SizedBox(height: 8),
                TextField(
                  controller: _busquedaController,
                  style: const TextStyle(color: SteamColors.light),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _buscarEnSteam(),
                  decoration: InputDecoration(
                    hintText: 'Nombre del juego',
                    filled: true,
                    fillColor: SteamColors.bgInput,
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.search, color: SteamColors.muted),
                      onPressed: _buscarEnSteam,
                    ),
                  ),
                ),
                if (_buscandoSteam)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation(SteamColors.blue),
                      ),
                    ),
                  )
                else
                  ..._resultadosSteam.map((juego) {
                    final seleccionado = _estaSeleccionado(juego['appid']);
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: seleccionado
                          ? const Icon(Icons.check_circle, color: SteamColors.green)
                          : const Icon(Icons.add_circle_outline, color: SteamColors.blue),
                      title: Text(
                        juego['nombre'] ?? '',
                        style: const TextStyle(color: SteamColors.light, fontSize: 13),
                      ),
                      onTap: () => _toggleJuego(juego),
                    );
                  }),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SteamButtonPrimary(
            label: _guardando
                ? (_editando ? 'Guardando...' : 'Publicando...')
                : (_editando ? 'Guardar cambios' : 'Publicar'),
            icon: _editando ? Icons.check_rounded : Icons.send_rounded,
            onTap: _guardando ? null : (_) => _publicar(),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
