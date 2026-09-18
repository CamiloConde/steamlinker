// Pantalla de login y registro
// Permite iniciar sesion o crear una cuenta nueva

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/navigation/app_navigator.dart';
import '../../../l10n/app_localizations.dart';
import '../../../theme/colors.dart';
import '../../../theme/radii.dart';
import '../../legal/screens/aviso_legal_screen.dart';
import '../../legal/screens/politica_privacidad_screen.dart';
import '../providers/auth_provider.dart';
import '../widgets/login_dev_server_chip.dart';
import '../../../widgets/steam_toast.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Controla si se muestra login o registro
  bool _mostrarRegistro = false;

  // Controladores de los campos de texto
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  bool _verPassword = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final t = AppLocalizations.of(context)!;
    // Validaciones antes de llamar al backend
    if (_emailController.text.trim().isEmpty) {
      showSteamToast(context, t.errorEmailRequired, SteamColors.orange);
      return;
    }

    if (!_emailController.text.trim().contains('@')) {
      showSteamToast(context, t.errorEmailInvalid, SteamColors.orange);
      return;
    }

    if (_passwordController.text.isEmpty) {
      showSteamToast(context, t.errorPasswordRequired, SteamColors.orange);
      return;
    }

    if (_passwordController.text.length < 4) {
      showSteamToast(context, t.errorPasswordTooShort, SteamColors.orange);
      return;
    }

    if (_mostrarRegistro && _usernameController.text.trim().isEmpty) {
      showSteamToast(context, t.errorUsernameRequired, SteamColors.orange);
      return;
    }

    if (_mostrarRegistro && _usernameController.text.trim().length < 3) {
      showSteamToast(context, t.errorUsernameTooShort, SteamColors.orange);
      return;
    }

    final auth = context.read<AuthProvider>();
    bool exito;

    if (_mostrarRegistro) {
      exito = await auth.registrar(
        username: _usernameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    } else {
      exito = await auth.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    }

    if (exito && mounted) {
      showSteamToast(context, t.sessionStarted, SteamColors.green);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final t = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: SteamColors.bgDeep,
      body: Stack(
        children: [
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 56),
              child: Container(
            width: 420,
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [

                // Logo y titulo
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [SteamColors.blue, SteamColors.teal],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: const Icon(Icons.sports_esports, color: Colors.white, size: 32),
                ),
                const SizedBox(height: 16),
                const Text(
                  'STEAMMATCH',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    color: SteamColors.light,
                  ),
                ),
                Text(
                  t.appTagline,
                  style: const TextStyle(fontSize: 13, color: SteamColors.textSec),
                ),
                const SizedBox(height: 40),

                // Tarjeta del formulario
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: SteamColors.bgCard,
                    borderRadius: BorderRadius.circular(SteamRadii.sm),
                    border: Border.all(color: SteamColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      Text(
                        _mostrarRegistro ? t.registerTitle : t.loginTitle,
                        style: const TextStyle(
                          color: SteamColors.light,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Campo username solo en registro
                      if (_mostrarRegistro) ...[
                        Text(t.usernameLabel,
                            style: const TextStyle(fontSize: 11, color: SteamColors.textSec, letterSpacing: 1)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _usernameController,
                          style: const TextStyle(color: SteamColors.light),
                          decoration: InputDecoration(
                            hintText: t.usernameHint,
                            hintStyle: const TextStyle(color: SteamColors.muted),
                            prefixIcon: const Icon(Icons.person_outline, size: 18, color: SteamColors.muted),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Campo email
                      Text(t.emailLabel,
                          style: const TextStyle(fontSize: 11, color: SteamColors.textSec, letterSpacing: 1)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(color: SteamColors.light),
                        decoration: InputDecoration(
                          hintText: t.emailHint,
                          hintStyle: const TextStyle(color: SteamColors.muted),
                          prefixIcon: const Icon(Icons.email_outlined, size: 18, color: SteamColors.muted),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Campo contrasena
                      Text(t.passwordLabel,
                          style: const TextStyle(fontSize: 11, color: SteamColors.textSec, letterSpacing: 1)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _passwordController,
                        obscureText: !_verPassword,
                        style: const TextStyle(color: SteamColors.light),
                        decoration: InputDecoration(
                          hintText: '••••••••',
                          hintStyle: const TextStyle(color: SteamColors.muted),
                          prefixIcon: const Icon(Icons.lock_outline, size: 18, color: SteamColors.muted),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _verPassword ? Icons.visibility_off : Icons.visibility,
                              size: 18,
                              color: SteamColors.muted,
                            ),
                            onPressed: () => setState(() => _verPassword = !_verPassword),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Mostrar error si existe
                      if (auth.error != null) ...[
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: SteamColors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(SteamRadii.sm),
                            border: Border.all(color: SteamColors.red.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: SteamColors.red, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  auth.error!,
                                  style: const TextStyle(
                                    color: SteamColors.red,
                                    fontSize: 12,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Boton principal
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: ElevatedButton(
                          onPressed: auth.cargando ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: SteamColors.blue,
                            foregroundColor: Colors.white,
                          ),
                          child: auth.cargando
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(_mostrarRegistro ? t.registerTitle : t.loginButton),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.only(top: 16),
                        decoration: const BoxDecoration(
                          border: Border(top: BorderSide(color: SteamColors.border)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              margin: const EdgeInsets.only(top: 1),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4),
                                gradient: const LinearGradient(
                                  colors: [SteamColors.blue, SteamColors.teal],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                t.steamLinkNote,
                                style: const TextStyle(
                                  color: SteamColors.textSec,
                                  fontSize: 12,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (_mostrarRegistro) ...[
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: const TextStyle(color: SteamColors.textSec, fontSize: 11.5, height: 1.4),
                        children: [
                          TextSpan(text: t.legalConsentPrefix),
                          TextSpan(
                            text: t.legalNoticeLink,
                            style: const TextStyle(color: SteamColors.blue, fontWeight: FontWeight.w600),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () => pushAppScreen(context, const AvisoLegalScreen()),
                          ),
                          TextSpan(text: t.legalConsentAnd),
                          TextSpan(
                            text: t.privacyPolicyLink,
                            style: const TextStyle(color: SteamColors.blue, fontWeight: FontWeight.w600),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () => pushAppScreen(context, const PoliticaPrivacidadScreen()),
                          ),
                          TextSpan(text: t.legalConsentSuffix),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),

                // Alternar entre login y registro
                Wrap(
                  alignment: WrapAlignment.center,
                  children: [
                    Text(
                      _mostrarRegistro ? t.haveAccountQuestion : t.noAccountQuestion,
                      style: const TextStyle(color: SteamColors.textSec, fontSize: 13),
                    ),
                    GestureDetector(
                      onTap: () => setState(() {
                        _mostrarRegistro = !_mostrarRegistro;
                      }),
                      child: Text(
                        _mostrarRegistro ? t.signInLink : t.signUpLink,
                        style: const TextStyle(
                          color: SteamColors.blue,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 10,
            child: SafeArea(
              top: false,
              child: Center(
                child: Text(
                  t.notAffiliated,
                  style: const TextStyle(color: SteamColors.muted, fontSize: 11),
                ),
              ),
            ),
          ),
          const Positioned(
            right: 16,
            bottom: 16,
            child: SafeArea(child: LoginDevServerChip()),
          ),
        ],
      ),
    );
  }
}