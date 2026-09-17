// Columna izquierda de escritorio (posición del wireframe): panel de accesos
// rápidos genérico, reusado por las pantallas con layout de 3 columnas.
// Cada pantalla decide qué secciones/items mostrar — nada se fabrica aquí.

import 'package:flutter/material.dart';
import '../theme/colors.dart';

class AccesosRapidosPanel extends StatelessWidget {
  final List<Widget> children;

  const AccesosRapidosPanel({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class AccesosSeccionTitulo extends StatelessWidget {
  final String texto;

  const AccesosSeccionTitulo(this.texto, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Text(
        texto,
        style: const TextStyle(
          color: SteamColors.textSec,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class AccesoRapidoItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool activo;
  final VoidCallback onTap;

  const AccesoRapidoItem({
    super.key,
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
