import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/locale_provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../theme/colors.dart';
import '../../../theme/radii.dart';
import '../../../widgets/steam_app_bar.dart';
import '../../../widgets/steam_card.dart';
import '../../../widgets/strength_bar.dart';
import '../../../widgets/steam_buttons.dart';
import '../../../widgets/toggle_row.dart';
import '../../../widgets/drop_field.dart';
import '../../../widgets/steam_toast.dart';
import '../../../core/auth/session_actions.dart';
import '../../../core/navigation/app_navigator.dart';
import '../../auth/providers/auth_provider.dart';
import '../../contacto/screens/contacto_screen.dart';
import '../../legal/screens/aviso_legal_screen.dart';
import '../../legal/screens/politica_privacidad_screen.dart';
import '../../perfil/providers/perfil_provider.dart';

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  static const List<String> _paises = [
    'Colombia',
    'México',
    'Argentina',
    'España',
    'EE.UU.',
  ];

  final _descripcionController = TextEditingController();

  String _pais = 'Colombia';
  String _originalDescripcion = '';
  String _originalPais = 'Colombia';
  bool _guardando = false;
  bool _tieneCambios = false;
  bool _perfilInicializado = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_perfilInicializado) {
      _perfilInicializado = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _cargarPerfil();
      });
    }
  }

  @override
  void dispose() {
    _descripcionController.dispose();
    super.dispose();
  }

  String _paisValido(dynamic raw) {
    if (raw == null) return 'Colombia';
    final s = raw.toString().trim();
    if (s.isEmpty) return 'Colombia';
    if (_paises.contains(s)) return s;
    if (s.length <= 3) {
      final nombre = _codeToPais(s);
      if (_paises.contains(nombre)) return nombre;
    }
    return 'Colombia';
  }

  void _aplicarDatosPerfil(Map<String, dynamic> perfil, Map<String, dynamic> usuario) {
    _descripcionController.text = perfil['descrip']?.toString() ?? '';
    _originalDescripcion = _descripcionController.text;
    _pais = _paisValido(perfil['pais'] ?? usuario['pais']);
    _originalPais = _pais;
    _tieneCambios = false;
  }

  static int? _parseId(dynamic id) {
    if (id is int) return id;
    return int.tryParse(id?.toString() ?? '');
  }

  static bool _idsMatch(dynamic a, dynamic b) {
    final ia = _parseId(a);
    final ib = _parseId(b);
    return ia != null && ib != null && ia == ib;
  }

  Future<void> _cargarPerfil() async {
    final auth = context.read<AuthProvider>();
    final perfilProv = context.read<PerfilProvider>();
    final usuario = auth.usuario;
    if (usuario == null) return;

    final userId = _parseId(usuario['id']);
    if (userId == null) return;

    final perfilActual = perfilProv.perfil;
    if (perfilActual != null && _idsMatch(perfilActual['id'], userId)) {
      if (mounted) {
        setState(() => _aplicarDatosPerfil(perfilActual, usuario));
      }
      return;
    }

    await perfilProv.cargarPerfil(userId);
    if (!mounted) return;
    final perfil = perfilProv.perfil;
    if (perfil != null) {
      setState(() => _aplicarDatosPerfil(perfil, usuario));
    } else {
      setState(() {
        _descripcionController.text = usuario['descrip']?.toString() ?? '';
        _originalDescripcion = _descripcionController.text;
        _pais = _paisValido(usuario['pais']);
        _originalPais = _pais;
        _tieneCambios = false;
      });
    }
  }

  String _paisToCode(String nombre) {
    switch (nombre) {
      case 'Colombia':
        return 'CO';
      case 'México':
        return 'MX';
      case 'Argentina':
        return 'AR';
      case 'España':
        return 'ES';
      case 'EE.UU.':
        return 'US';
      default:
        return nombre.length <= 5 ? nombre : nombre.substring(0, 5);
    }
  }

  String _codeToPais(String code) {
    switch (code.toUpperCase()) {
      case 'CO':
        return 'Colombia';
      case 'MX':
        return 'México';
      case 'AR':
        return 'Argentina';
      case 'ES':
        return 'España';
      case 'US':
        return 'EE.UU.';
      default:
        return _paises.contains(code) ? code : 'Colombia';
    }
  }

  void _marcarCambio([bool valor = true]) {
    if (_tieneCambios != valor) {
      setState(() => _tieneCambios = valor);
    }
  }

  void _restaurarPerfil() {
    _descripcionController.text = _originalDescripcion;
    _pais = _originalPais;
    _marcarCambio(false);
  }

  Future<void> _guardarPerfil() async {
    final perfilProv = context.read<PerfilProvider>();
    final auth = context.read<AuthProvider>();

    setState(() => _guardando = true);
    final exito = await perfilProv.editarPerfil(
      descripcion: _descripcionController.text.trim(),
      pais: _paisToCode(_pais),
    );
    if (!mounted) return;

    if (exito) {
      _originalDescripcion = _descripcionController.text.trim();
      _originalPais = _pais;
      _marcarCambio(false);
      auth.actualizarUsuario({
        'descrip': _originalDescripcion,
        'pais': _originalPais,
      });
      showSteamToast(
        context,
        'Perfil actualizado correctamente',
        SteamColors.green,
      );
    } else {
      showSteamToast(
        context,
        perfilProv.error ?? 'Error al guardar perfil',
        Colors.red,
      );
    }
    setState(() => _guardando = false);
  }

  List<Widget> _tarjetasConfiguracion({
    required Map<String, dynamic> usuario,
  }) {
    return [
      _ProfileCard(
        usuario: usuario,
        descripcionController: _descripcionController,
        pais: _pais,
        guardando: _guardando,
        hasChanges: _tieneCambios,
        onGuardar: _guardarPerfil,
        onPaisChanged: (value) {
          _marcarCambio();
          setState(() => _pais = value);
        },
        onDescripcionChanged: (_) => _marcarCambio(),
        onCancelar: _restaurarPerfil,
      ),
      const SizedBox(height: 16),
      const _SecurityCard(),
      const SizedBox(height: 16),
      const _PrivacyCard(),
      const SizedBox(height: 16),
      const _LanguageCard(),
      const SizedBox(height: 16),
      const _LegalCard(),
      const SizedBox(height: 16),
      const _DangerCard(),
    ];
  }

  Widget _cuerpoPrincipal(
    Map<String, dynamic> usuario,
    PerfilProvider perfilProv,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (!perfilProv.cargando &&
            perfilProv.perfil == null &&
            perfilProv.error != null) ...[
          Text(
            perfilProv.error ?? 'No se pudo cargar tu perfil',
            style: const TextStyle(color: SteamColors.light),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          SteamButtonPrimary(
            label: 'Reintentar',
            icon: Icons.refresh,
            onTap: (_) => _cargarPerfil(),
          ),
          const SizedBox(height: 16),
        ],
        if (perfilProv.cargando && perfilProv.perfil == null)
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation(SteamColors.blue),
                ),
              ),
            ),
          ),
        ..._tarjetasConfiguracion(usuario: usuario),
        const SizedBox(height: 32),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final perfilProv = context.watch<PerfilProvider>();
    final usuario = auth.usuario;

    return Scaffold(
      backgroundColor: SteamColors.bgDeep,
      appBar: const SteamAppBar(title: 'CONFIGURACIÓN', showBack: true),
      body: usuario == null
          ? const Center(
              child: Text(
                'Debes iniciar sesión para ver esta pantalla',
                style: TextStyle(color: SteamColors.light),
              ),
            )
          : SafeArea(
              child: _cuerpoPrincipal(usuario, perfilProv),
            ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final Map<String, dynamic> usuario;
  final TextEditingController descripcionController;
  final String pais;
  final bool guardando;
  final bool hasChanges;
  final VoidCallback onGuardar;
  final ValueChanged<String> onPaisChanged;
  final ValueChanged<String> onDescripcionChanged;
  final VoidCallback onCancelar;

  const _ProfileCard({
    required this.usuario,
    required this.descripcionController,
    required this.pais,
    required this.guardando,
    required this.hasChanges,
    required this.onGuardar,
    required this.onPaisChanged,
    required this.onDescripcionChanged,
    required this.onCancelar,
  });

  @override
  Widget build(BuildContext context) {
    return SteamCard(
      icon: Icons.person_outline,
      title: 'Información Personal',
      child: Column(
        children: [
          TextFormField(
            initialValue: usuario['username'] ?? '',
            readOnly: true,
            decoration: InputDecoration(
              labelText: 'Usuario',
              filled: true,
              fillColor: SteamColors.bgInput,
            ),
            style: const TextStyle(color: SteamColors.light),
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: usuario['email'] ?? '',
            readOnly: true,
            decoration: InputDecoration(
              labelText: 'Correo electrónico',
              filled: true,
              fillColor: SteamColors.bgInput,
            ),
            style: const TextStyle(color: SteamColors.light),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: descripcionController,
            maxLines: 4,
            onChanged: onDescripcionChanged,
            decoration: InputDecoration(
              labelText: 'Descripción',
              hintText: 'Cuéntanos sobre ti',
              filled: true,
              fillColor: SteamColors.bgInput,
            ),
            style: const TextStyle(color: SteamColors.light),
          ),
          const SizedBox(height: 12),
          DropField(
            label: 'País',
            value: pais,
            items: _AccountSettingsScreenState._paises,
            onChanged: onPaisChanged,
          ),
          const Divider(color: SteamColors.border, height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              SteamButtonOutline(
                label: 'Cancelar',
                onTap: onCancelar,
                fullWidth: false,
                compact: true,
              ),
              const SizedBox(width: 10),
              SteamButtonPrimary(
                label: guardando ? 'Guardando...' : 'Guardar',
                icon: Icons.save_outlined,
                fullWidth: false,
                compact: true,
                onTap: guardando || !hasChanges ? (_) {} : (_) => onGuardar(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SecurityCard extends StatefulWidget {
  const _SecurityCard();

  @override
  State<_SecurityCard> createState() => _SecurityCardState();
}

class _SecurityCardState extends State<_SecurityCard> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String _newPw = '';
  bool _cambiando = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _actualizarContrasena() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _cambiando = true);
    final auth = context.read<AuthProvider>();
    final exitoso = await auth.cambiarContrasena(
      contrasenaActual: _currentPasswordController.text.trim(),
      nuevaContrasena: _newPasswordController.text.trim(),
    );
    if (!mounted) return;

    if (exitoso) {
      showSteamToast(
        context,
        'Contraseña actualizada correctamente',
        SteamColors.green,
      );
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      setState(() => _newPw = '');
    } else {
      showSteamToast(
        context,
        auth.error ?? 'Error al cambiar contraseña',
        Colors.red,
      );
    }
    setState(() => _cambiando = false);
  }

  @override
  Widget build(BuildContext context) {
    return SteamCard(
      icon: Icons.lock_outline,
      title: 'Seguridad',
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(
              controller: _currentPasswordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Contraseña actual',
                hintText: '••••••••',
                filled: true,
                fillColor: SteamColors.bgInput,
              ),
              style: const TextStyle(color: SteamColors.light),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Introduce tu contraseña actual';
                }
                if (value.length < 6) {
                  return 'Contraseña incorrecta';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _newPasswordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Nueva contraseña',
                hintText: 'Mínimo 8 caracteres',
                filled: true,
                fillColor: SteamColors.bgInput,
              ),
              style: const TextStyle(color: SteamColors.light),
              onChanged: (value) => setState(() => _newPw = value),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Introduce una nueva contraseña';
                }
                if (value.length < 8) {
                  return 'Mínimo 8 caracteres';
                }
                return null;
              },
            ),
            if (_newPw.isNotEmpty) ...[
              const SizedBox(height: 8),
              StrengthBar(password: _newPw),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Confirmar contraseña',
                hintText: 'Repite la contraseña',
                filled: true,
                fillColor: SteamColors.bgInput,
              ),
              style: const TextStyle(color: SteamColors.light),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Confirma la contraseña';
                }
                if (value != _newPasswordController.text) {
                  return 'Las contraseñas no coinciden';
                }
                return null;
              },
            ),
            const Divider(color: SteamColors.border, height: 1),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: SteamButtonPrimary(
                label: _cambiando ? 'Actualizando...' : 'Actualizar contraseña',
                icon: Icons.lock_reset_outlined,
                onTap: (_) {
                  if (!_cambiando) {
                    _actualizarContrasena();
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrivacyCard extends StatefulWidget {
  const _PrivacyCard();

  @override
  State<_PrivacyCard> createState() => _PrivacyCardState();
}

class _PrivacyCardState extends State<_PrivacyCard> {
  bool publicProfile = true;
  bool friendNotifs = true;
  bool twoFA = false;
  bool _hasChanges = false;
  bool _saving = false;
  bool _inicializado = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_inicializado) {
      _inicializado = true;
      _cargarPrivacidad();
    }
  }

  Future<void> _cargarPrivacidad() async {
    final perfilProv = context.read<PerfilProvider>();
    if (perfilProv.privacidad != null) {
      setState(() {
        publicProfile = perfilProv.privacidad!['perfil_publico'] ?? true;
        friendNotifs = perfilProv.privacidad!['notificaciones_amigos'] ?? true;
        twoFA = perfilProv.privacidad!['dos_factor'] ?? false;
      });
    }
  }

  void _marcarCambio() {
    if (!_hasChanges) {
      setState(() => _hasChanges = true);
    }
  }

  Future<void> _guardarPrivacidad() async {
    final perfilProv = context.read<PerfilProvider>();
    setState(() => _saving = true);

    final exito = await perfilProv.guardarPrivacidad(
      perfilPublico: publicProfile,
      mostrarBiblioteca: true, // Siempre mostrar biblioteca según el diseño
      notificacionesAmigos: friendNotifs,
      dosFactor: twoFA,
    );

    if (!mounted) return;
    setState(() {
      _saving = false;
      if (exito) {
        _hasChanges = false;
      }
    });

    if (exito) {
      showSteamToast(context, 'Preferencias guardadas', SteamColors.green);
    } else {
      showSteamToast(
        context,
        perfilProv.error ?? 'No fue posible guardar las preferencias',
        Colors.red,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SteamCard(
      icon: Icons.shield_outlined,
      title: 'Privacidad y Notificaciones',
      child: Column(
        children: [
          ToggleRow(
            title: 'Perfil público',
            description: 'Otros jugadores pueden ver tu perfil y biblioteca',
            value: publicProfile,
            onChanged: (v) {
              setState(() => publicProfile = v);
              _marcarCambio();
            },
          ),
          ToggleRow(
            title: 'Notificaciones de amigos',
            description: 'Alerta cuando tus amigos se conecten',
            value: friendNotifs,
            decorativo: true,
            onChanged: (v) {
              setState(() => friendNotifs = v);
              _marcarCambio();
            },
          ),
          ToggleRow(
            title: 'Autenticación en dos pasos',
            description: 'Capa extra de seguridad para tu cuenta',
            value: twoFA,
            decorativo: true,
            onChanged: (v) {
              setState(() => twoFA = v);
              _marcarCambio();
            },
            showDivider: false,
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: SteamButtonPrimary(
              label: _saving ? 'Guardando...' : 'Guardar ajustes',
              icon: Icons.save_outlined,
              onTap: !_hasChanges || _saving
                  ? (_) {}
                  : (_) => _guardarPrivacidad(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Selector ES/EN. Solo login/registro, el bottom nav y el sidebar de
/// escritorio están traducidos todavía — ver HANDOFF.md, el resto de la
/// app sigue en español sin importar lo que se elija acá.
class _LanguageCard extends StatelessWidget {
  const _LanguageCard();

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final localeProv = context.watch<LocaleProvider>();
    final esEspanol = localeProv.locale.languageCode == 'es';

    return SteamCard(
      icon: Icons.language_outlined,
      title: t.languageSectionTitle,
      child: Row(
        children: [
          Expanded(
            child: _OpcionIdioma(
              label: t.languageSpanish,
              seleccionado: esEspanol,
              onTap: () => context.read<LocaleProvider>().cambiarA('es'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _OpcionIdioma(
              label: t.languageEnglish,
              seleccionado: !esEspanol,
              onTap: () => context.read<LocaleProvider>().cambiarA('en'),
            ),
          ),
        ],
      ),
    );
  }
}

class _OpcionIdioma extends StatelessWidget {
  final String label;
  final bool seleccionado;
  final VoidCallback onTap;

  const _OpcionIdioma({
    required this.label,
    required this.seleccionado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: seleccionado ? SteamColors.blue : SteamColors.bgPanel,
      borderRadius: BorderRadius.circular(SteamRadii.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(SteamRadii.sm),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(SteamRadii.sm),
            border: Border.all(color: seleccionado ? SteamColors.blue : SteamColors.border),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: seleccionado ? Colors.white : SteamColors.light,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _LegalCard extends StatelessWidget {
  const _LegalCard();

  @override
  Widget build(BuildContext context) {
    return SteamCard(
      icon: Icons.gavel_outlined,
      title: 'Ayuda y legal',
      child: Column(
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.mail_outline, color: SteamColors.muted, size: 20),
            title: const Text('Contacto y sugerencias', style: TextStyle(color: SteamColors.light, fontSize: 13.5)),
            trailing: const Icon(Icons.chevron_right, color: SteamColors.muted, size: 18),
            onTap: () => pushAppScreen(context, const ContactoScreen()),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.description_outlined, color: SteamColors.muted, size: 20),
            title: const Text('Aviso legal', style: TextStyle(color: SteamColors.light, fontSize: 13.5)),
            trailing: const Icon(Icons.chevron_right, color: SteamColors.muted, size: 18),
            onTap: () => pushAppScreen(context, const AvisoLegalScreen()),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.privacy_tip_outlined, color: SteamColors.muted, size: 20),
            title: const Text('Política de privacidad', style: TextStyle(color: SteamColors.light, fontSize: 13.5)),
            trailing: const Icon(Icons.chevron_right, color: SteamColors.muted, size: 18),
            onTap: () => pushAppScreen(context, const PoliticaPrivacidadScreen()),
          ),
        ],
      ),
    );
  }
}

class _DangerCard extends StatelessWidget {
  const _DangerCard();

  Future<void> _mostrarConfirmacion(BuildContext context) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Eliminar cuenta'),
          content: const Text(
            '¿Estás seguro que deseas eliminar tu cuenta? Esta acción no se puede deshacer.',
          ),
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

    if (confirmado != true || !context.mounted) return;

    final auth = context.read<AuthProvider>();
    final exito = await auth.eliminarCuenta();
    if (!context.mounted) return;

    if (exito) {
      showSteamToast(
        context,
        'Cuenta eliminada correctamente',
        SteamColors.green,
      );
    } else {
      showSteamToast(
        context,
        auth.error ?? 'Error al eliminar cuenta',
        Colors.red,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SteamCard(
      icon: Icons.warning_amber_outlined,
      title: 'Zona de Peligro',
      accent: SteamColors.red,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Estas acciones son irreversibles. Procede con precaución.',
            style: TextStyle(color: SteamColors.textSec, fontSize: 12.5),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              SteamButtonDanger(
                label: 'Eliminar cuenta',
                icon: Icons.delete_outline,
                onTap: () => _mostrarConfirmacion(context),
              ),
              SteamButtonDanger(
                label: 'Cerrar sesión',
                icon: Icons.logout,
                onTap: () => confirmarYCerrarSesion(context),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
