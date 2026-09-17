import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../theme/colors.dart';
import '../../../theme/radii.dart';
import '../../../widgets/steam_app_bar.dart';
import '../../../core/auth/session_actions.dart';
import '../../../core/auth/user_role.dart';
import '../../auth/providers/auth_provider.dart';
import '../../busqueda/screens/busqueda_screen.dart';
import '../../chat/screens/chat_screen.dart';
import '../../amistad/screens/amistad_screen.dart';
import '../../descubrir/screens/descubrir_gamers_screen.dart';
import '../../perfil/screens/perfil_screen.dart';
import '../../publicaciones/screens/publicaciones_screen.dart';

class HomeScreen extends StatefulWidget {
  /// Cuando se embebe en el sidebar de escritorio (ResponsiveShell), las
  /// tarjetas de acceso rápido cambian de sección en vez de empujar una
  /// pantalla nueva sobre el sidebar. En móvil queda null y se usa
  /// Navigator.push como siempre.
  final ValueChanged<int>? onNavigateIndex;

  const HomeScreen({super.key, this.onNavigateIndex});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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
    return Scaffold(
      backgroundColor: SteamColors.bgDeep,
      appBar: SteamAppBar(
        title: 'INICIO',
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: SteamColors.muted),
            tooltip: 'Cerrar sesión',
            onPressed: () => confirmarYCerrarSesion(context),
          ),
        ],
      ),
      body: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          if (auth.usuario == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation(SteamColors.blue),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Cargando datos...',
                    style: TextStyle(color: SteamColors.light),
                  ),
                ],
              ),
            );
          }

          final usuario = auth.usuario!;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // ── Tarjeta de Bienvenida ────────────────────────────
                Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2A4A6B), SteamColors.teal],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(SteamRadii.sm),
                    border: Border.all(color: SteamColors.blue, width: 1),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
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
                            width: 56,
                            height: 56,
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
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Tu hub para conectar con gamers',
                        style: TextStyle(
                          color: SteamColors.textSec,
                          fontSize: 13.5,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── Información del Usuario ──────────────────────────
                Container(
                  decoration: BoxDecoration(
                    color: SteamColors.bgCard,
                    borderRadius: BorderRadius.circular(SteamRadii.sm),
                    border: Border.all(color: SteamColors.border),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _InfoRow(
                        icon: Icons.email_outlined,
                        label: 'Email',
                        value: usuario['email'] ?? 'N/A',
                      ),
                      const Divider(color: SteamColors.border, height: 20),
                      _InfoRow(
                        icon: Icons.public,
                        label: 'País',
                        value: usuario['pais'] ?? 'No especificado',
                      ),
                      const Divider(color: SteamColors.border, height: 20),
                      _InfoRow(
                        icon: Icons.account_box_outlined,
                        label: 'Tipo de Cuenta',
                        value: etiquetaTipoCuenta(usuario),
                        valueColor: esUsuarioAdmin(usuario)
                            ? SteamColors.orange
                            : SteamColors.light,
                      ),
                      const Divider(color: SteamColors.border, height: 20),
                      _InfoRow(
                        icon: Icons.trending_up,
                        label: 'Estado',
                        value: 'En línea',
                        valueColor: SteamColors.green,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── Secciones Rápidas ────────────────────────────────
                _QuickAccessCard(
                  icon: Icons.people_outline,
                  title: 'Descubre Gamers',
                  description: 'Encuentra compañeros de juego',
                  color: SteamColors.purple,
                  onTap: () => _ir(1, const DescubrirGamersScreen()),
                ),
                const SizedBox(height: 12),
                _QuickAccessCard(
                  icon: Icons.group_outlined,
                  title: 'Amigos',
                  description: 'Solicitudes y lista de amigos',
                  color: SteamColors.green,
                  onTap: () => _ir(3, const AmistadScreen()),
                ),
                const SizedBox(height: 12),
                _QuickAccessCard(
                  icon: Icons.search_outlined,
                  title: 'Buscar juegos',
                  description: 'Explora la tienda Steam',
                  color: SteamColors.teal,
                  onTap: () => _ir(4, const BusquedaScreen()),
                ),
                const SizedBox(height: 12),
                _QuickAccessCard(
                  icon: Icons.sports_esports_outlined,
                  title: 'Mis Juegos',
                  description: 'Administra tu biblioteca',
                  color: SteamColors.teal,
                  onTap: () => _ir(7, const PerfilScreen()),
                ),
                const SizedBox(height: 12),
                _QuickAccessCard(
                  icon: Icons.chat_outlined,
                  title: 'Mensajes',
                  description: 'Comunícate con otros usuarios',
                  color: SteamColors.blue,
                  onTap: () => _ir(5, const ChatScreen()),
                ),
                const SizedBox(height: 12),
                _QuickAccessCard(
                  icon: Icons.campaign_outlined,
                  title: 'Publicaciones',
                  description: 'Explora avisos y ofertas de juego',
                  color: SteamColors.orange,
                  onTap: () => _ir(2, const PublicacionesScreen()),
                ),

                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor = SteamColors.light,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: SteamColors.blue),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                color: SteamColors.textSec,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _QuickAccessCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final VoidCallback? onTap;

  const _QuickAccessCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withAlpha(38),
                    borderRadius: BorderRadius.circular(SteamRadii.sm),
                    border: Border.all(color: color, width: 1.5),
                  ),
                  child: Center(
                    child: Icon(icon, size: 22, color: color),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: SteamColors.light,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        description,
                        style: const TextStyle(
                          color: SteamColors.textSec,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_rounded, color: SteamColors.muted, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
