import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/pais_util.dart';
import '../../../core/constants/publicacion_constants.dart';
import '../../../theme/colors.dart';
import '../../../widgets/badge_origen_juego.dart';
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

  /// Preselecciona el tipo al crear (no aplica en modo edición) -- pedido
  /// explícito del usuario: publicar desde la pestaña "Jugar ahora" u
  /// "Otro" del conmutador de escritorio debería arrancar ya con ese tipo
  /// en vez de siempre el primero de la lista.
  final String? tipoInicial;

  const CrearPublicacionScreen({
    super.key,
    this.publicacionExistente,
    this.tipoInicial,
  });

  @override
  State<CrearPublicacionScreen> createState() => _CrearPublicacionScreenState();
}

class _CrearPublicacionScreenState extends State<CrearPublicacionScreen> {
  final _tituloController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _busquedaController = TextEditingController();
  final _busquedaBibliotecaController = TextEditingController();
  final _cuposController = TextEditingController();

  late String _tipoEtiqueta;
  String _paisEtiqueta = PaisUtil.todos;
  final List<Map<String, dynamic>> _juegosSeleccionados = [];
  bool _guardando = false;
  bool _buscandoSteam = false;
  List<dynamic> _resultadosSteam = [];
  String _busquedaBiblioteca = '';

  // Pedido explícito del usuario: con una biblioteca grande, pintar
  // siempre todos los checkboxes obligaba a bajar mucho para llegar al
  // botón de publicar. Colapsada por defecto -- se expande sola al
  // escribir algo en el buscador, o si el usuario toca "Ver todos".
  bool _bibliotecaExpandida = false;

  bool get _editando => widget.publicacionExistente != null;

  bool get _requiereSteam => PublicacionConstants.requiereSteam(
    PublicacionConstants.valorTipoCrear(_tipoEtiqueta),
  );

  // Antes esto se filtraba a solo juegos verificados por Steam para
  // familia/miembros -- pero el usuario reportó un caso real: tiene
  // juegos de verdad (ej. biblioteca compartida de su Familia de Steam)
  // que la API pública de Steam no puede confirmar, así que nunca
  // aparecían acá y no podía ofrecerlos. Ahora se muestra toda la
  // biblioteca (verificada + manual) para cualquier tipo, cada juego con
  // su insignia STEAM/MANUAL -- el backend guarda ese origen real por
  // publicación (no lo que mande el cliente), así que la insignia sigue
  // siendo confiable para quien vea la publicación después.
  //
  // También filtra por el buscador local de biblioteca -- pedido
  // explícito: con una biblioteca grande (100+ juegos) ir marcando uno
  // por uno a pura vista/scroll es tedioso, esto deja escribir el nombre
  // y saltar directo en vez de desplazarse por toda la lista.
  List<dynamic> _bibliotecaBase(PerfilProvider perfilProv) => perfilProv.juegos;

  List<dynamic> _bibliotecaMostrada(PerfilProvider perfilProv) {
    final base = _bibliotecaBase(perfilProv);
    if (_busquedaBiblioteca.trim().isEmpty) return base;
    final q = _busquedaBiblioteca.trim().toLowerCase();
    return base
        .where((j) => (j['nombre']?.toString() ?? '').toLowerCase().contains(q))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargarBiblioteca());

    _tipoEtiqueta =
        (widget.tipoInicial != null &&
            PublicacionConstants.tiposCrearEtiquetas.contains(
              widget.tipoInicial,
            ))
        ? widget.tipoInicial!
        : PublicacionConstants.tiposCrearEtiquetas.first;

    final pub = widget.publicacionExistente;
    if (pub != null) {
      _tituloController.text = (pub['titulo_publi'] as String?) ?? '';
      _descripcionController.text = (pub['descrip_publi'] as String?) ?? '';
      final cupos = pub['cupos_totales'];
      if (cupos != null) _cuposController.text = '$cupos';
      final tipo = pub['tipo_publi'] as String?;
      if (tipo != null &&
          PublicacionConstants.tipoEtiquetas.containsKey(tipo)) {
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
    _busquedaBibliotecaController.dispose();
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
    final cuposTotales =
        tipo != 'otro' && tipo != 'busco_familia' && cuposTexto.isNotEmpty
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
      appBar: SteamAppBar(
        title: _editando ? 'EDITAR PUBLICACIÓN' : 'NUEVA PUBLICACIÓN',
      ),
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
                  onChanged: _editando
                      ? null
                      : (v) => setState(() => _tipoEtiqueta = v),
                ),
                if (PublicacionConstants.requiereSteam(
                  PublicacionConstants.valorTipoCrear(_tipoEtiqueta),
                ))
                  const Padding(
                    padding: EdgeInsets.only(top: 4, bottom: 8),
                    child: Text(
                      'Necesitas tu cuenta de Steam vinculada para publicar esto.',
                      style: TextStyle(
                        color: SteamColors.textSec,
                        fontSize: 11,
                      ),
                    ),
                  ),
                // "Cupos" no tiene sentido semántico en busco_familia: ahí
                // quien publica es UNA persona buscando unirse a una
                // familia, no reclutando gente -- no hay "cuántos cupos"
                // que ofrecer. Pedido explícito del usuario al notar que
                // el campo aparecía igual ahí sin ningún propósito real.
                if (!['otro', 'busco_familia'].contains(
                  PublicacionConstants.valorTipoCrear(_tipoEtiqueta),
                )) ...[
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
                      helperText:
                          'Si lo dejas vacío, la publicación no mostrará límite de cupos.',
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
                      // El backend calcula "tengo"/"busco" solo, según si
                      // el juego está en tu biblioteca -- acá se
                      // previsualiza con la misma regla, para que quede
                      // claro antes de publicar cómo se va a mostrar cada
                      // chip (evita el caso que reportó el usuario: un
                      // juego que solo pide aparecía como si lo tuviera).
                      final tengo = perfilProv.juegos.any(
                        (mio) => mio['appid'] == j['appid'],
                      );
                      return InputChip(
                        avatar: Icon(
                          tengo
                              ? Icons.check_circle_outline
                              : Icons.star_outline,
                          size: 16,
                          color: tengo ? SteamColors.teal : SteamColors.muted,
                        ),
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
                    const Expanded(
                      child: Text(
                        'Tu biblioteca',
                        style: TextStyle(
                          color: SteamColors.textSec,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    if (_bibliotecaMostrada(perfilProv).isNotEmpty)
                      TextButton(
                        onPressed: () => _marcarTodosVerificados(
                          _bibliotecaMostrada(perfilProv),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          _bibliotecaMostrada(
                                perfilProv,
                              ).every((j) => _estaSeleccionado(j['appid']))
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
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Elige los juegos que quieres mostrar. Los marcados '
                    'STEAM los confirma tu cuenta directamente; los MANUAL '
                    'los agregaste tú (por ejemplo, biblioteca compartida de '
                    'tu Familia de Steam, que no se puede verificar por API).',
                    style: TextStyle(color: SteamColors.textSec, fontSize: 11),
                  ),
                ),
                // Con una biblioteca grande, ir marcando uno por uno a pura
                // vista era tedioso -- pedido explícito. Filtra la lista de
                // abajo en vivo, no pega a ningún backend.
                if (_bibliotecaBase(perfilProv).length > 6)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: TextField(
                      controller: _busquedaBibliotecaController,
                      onChanged: (v) => setState(() => _busquedaBiblioteca = v),
                      style: const TextStyle(
                        color: SteamColors.light,
                        fontSize: 13,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Buscar en tu biblioteca...',
                        prefixIcon: const Icon(
                          Icons.search,
                          color: SteamColors.muted,
                          size: 18,
                        ),
                        suffixIcon: _busquedaBiblioteca.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(
                                  Icons.clear,
                                  color: SteamColors.muted,
                                  size: 18,
                                ),
                                onPressed: () {
                                  _busquedaBibliotecaController.clear();
                                  setState(() => _busquedaBiblioteca = '');
                                },
                              ),
                        filled: true,
                        fillColor: SteamColors.bgInput,
                      ),
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
                else if (_bibliotecaBase(perfilProv).isEmpty)
                  const Text(
                    'Agrega juegos a tu perfil para asociarlos a la publicación.',
                    style: TextStyle(color: SteamColors.textSec, fontSize: 12),
                  )
                else if (_busquedaBiblioteca.trim().isEmpty &&
                    !_bibliotecaExpandida &&
                    _bibliotecaBase(perfilProv).length > 6)
                  // Colapsada por defecto -- pedido explícito del usuario:
                  // pintar siempre todos los checkboxes de una biblioteca
                  // grande obligaba a bajar mucho para llegar a publicar.
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: InkWell(
                      onTap: () => setState(() => _bibliotecaExpandida = true),
                      child: Row(
                        children: [
                          Text(
                            'Ver toda tu biblioteca (${_bibliotecaBase(perfilProv).length})',
                            style: const TextStyle(
                              color: SteamColors.blue,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Icon(
                            Icons.expand_more,
                            color: SteamColors.blue,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  )
                else if (_bibliotecaMostrada(perfilProv).isEmpty)
                  Text(
                    'Ningún juego coincide con "${_busquedaBiblioteca.trim()}".',
                    style: const TextStyle(
                      color: SteamColors.textSec,
                      fontSize: 12,
                    ),
                  )
                else ...[
                  if (_bibliotecaExpandida &&
                      _busquedaBiblioteca.trim().isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: InkWell(
                        onTap: () =>
                            setState(() => _bibliotecaExpandida = false),
                        child: const Row(
                          children: [
                            Text(
                              'Ocultar lista',
                              style: TextStyle(
                                color: SteamColors.blue,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Icon(
                              Icons.expand_less,
                              color: SteamColors.blue,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ..._bibliotecaMostrada(perfilProv).map((juego) {
                    final seleccionado = _estaSeleccionado(juego['appid']);
                    return CheckboxListTile(
                      value: seleccionado,
                      onChanged: (_) => _toggleJuego(juego),
                      activeColor: SteamColors.blue,
                      title: Row(
                        children: [
                          Flexible(
                            child: Text(
                              juego['nombre'] ?? 'Juego',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: SteamColors.light,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          BadgeOrigenJuego(esSteam: juego['origen'] == 'steam'),
                        ],
                      ),
                      subtitle: Text(
                        '${juego['horas'] ?? 0} h jugadas',
                        style: const TextStyle(
                          color: SteamColors.textSec,
                          fontSize: 11,
                        ),
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    );
                  }),
                ],
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
                      style: TextStyle(
                        color: SteamColors.textSec,
                        fontSize: 11,
                      ),
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
                          ? const Icon(
                              Icons.check_circle,
                              color: SteamColors.green,
                            )
                          : const Icon(
                              Icons.add_circle_outline,
                              color: SteamColors.blue,
                            ),
                      title: Text(
                        juego['nombre'] ?? '',
                        style: const TextStyle(
                          color: SteamColors.light,
                          fontSize: 13,
                        ),
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
