// Pantalla de login y registro
// Permite iniciar sesion o crear una cuenta nueva

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../theme/radii.dart';
import '../providers/auth_provider.dart';
import '../widgets/login_dev_server_chip.dart';

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
    // Validaciones antes de llamar al backend
    if (_emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El correo es obligatorio')),
      );
      return;
    }

    if (!_emailController.text.trim().contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El correo no tiene un formato valido')),
      );
      return;
    }

    if (_passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La contrasena es obligatoria')),
      );
      return;
    }

    if (_passwordController.text.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La contrasena debe tener al menos 4 caracteres')),
      );
      return;
    }

    if (_mostrarRegistro && _usernameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El nombre de usuario es obligatorio')),
      );
      return;
    }

    if (_mostrarRegistro && _usernameController.text.trim().length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El usuario debe tener al menos 3 caracteres')),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sesion iniciada correctamente')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
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
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF1A9FFF),
                  ),
                  child: const Icon(Icons.games, color: Colors.white, size: 32),
                ),
                const SizedBox(height: 16),
                const Text(
                  'STEAMLINKER',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    color: Colors.white,
                  ),
                ),
                const Text(
                  'Tu conector de comunidad gamer',
                  style: TextStyle(fontSize: 13, color: Color(0xFF8B949E)),
                ),
                const SizedBox(height: 40),

                // Tarjeta del formulario
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161B22),
                    borderRadius: BorderRadius.circular(SteamRadii.sm),
                    border: Border.all(color: const Color(0xFF30363D)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      Text(
                        _mostrarRegistro ? 'CREAR CUENTA' : 'INICIAR SESION',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Campo username solo en registro
                      if (_mostrarRegistro) ...[
                        const Text('NOMBRE DE USUARIO',
                            style: TextStyle(fontSize: 11, color: Color(0xFF8B949E), letterSpacing: 1)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _usernameController,
                          decoration: const InputDecoration(
                            hintText: 'Tu nombre de usuario',
                            prefixIcon: Icon(Icons.person_outline, size: 18),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Campo email
                      const Text('CORREO',
                          style: TextStyle(fontSize: 11, color: Color(0xFF8B949E), letterSpacing: 1)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          hintText: 'tu@correo.com',
                          prefixIcon: Icon(Icons.email_outlined, size: 18),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Campo contrasena
                      const Text('CONTRASEÑA',
                          style: TextStyle(fontSize: 11, color: Color(0xFF8B949E), letterSpacing: 1)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _passwordController,
                        obscureText: !_verPassword,
                        decoration: InputDecoration(
                          hintText: '••••••••',
                          prefixIcon: const Icon(Icons.lock_outline, size: 18),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _verPassword ? Icons.visibility_off : Icons.visibility,
                              size: 18,
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
                            color: Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(SteamRadii.sm),
                            border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: Colors.red, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  auth.error!,
                                  style: const TextStyle(
                                    color: Colors.red,
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
                          child: auth.cargando
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(_mostrarRegistro ? 'CREAR CUENTA' : 'INGRESAR'),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.only(top: 16),
                        decoration: const BoxDecoration(
                          border: Border(top: BorderSide(color: Color(0xFF30363D))),
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
                                  colors: [Color(0xFF3B82F6), Color(0xFF22D3EE)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                            ),
                            const SizedBox(width: 9),
                            const Expanded(
                              child: Text(
                                'Vincular tu cuenta de Steam es un paso posterior, '
                                'dentro de Perfil. Hace falta solo para publicar o '
                                'matchear en Familia.',
                                style: TextStyle(
                                  color: Color(0xFF8B949E),
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
                const SizedBox(height: 16),

                // Alternar entre login y registro
                Wrap(
                  alignment: WrapAlignment.center,
                  children: [
                    Text(
                      _mostrarRegistro ? '¿Ya tienes cuenta? ' : '¿No tienes cuenta? ',
                      style: const TextStyle(color: Color(0xFF8B949E), fontSize: 13),
                    ),
                    GestureDetector(
                      onTap: () => setState(() {
                        _mostrarRegistro = !_mostrarRegistro;
                      }),
                      child: Text(
                        _mostrarRegistro ? 'Inicia sesion' : 'Crear cuenta gratis',
                        style: const TextStyle(
                          color: Color(0xFF1A9FFF),
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
          const Positioned(
            left: 0,
            right: 0,
            bottom: 10,
            child: SafeArea(
              top: false,
              child: Center(
                child: Text(
                  'No afiliado a Valve Corporation',
                  style: TextStyle(color: Color(0xFF8B949E), fontSize: 11),
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