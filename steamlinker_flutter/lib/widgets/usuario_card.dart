import 'package:flutter/material.dart';
import '../core/constants/pais_util.dart';
import '../theme/colors.dart';
import '../theme/radii.dart';

class UsuarioCard extends StatelessWidget {
  final Map<String, dynamic> usuario;
  final VoidCallback? onTap;
  final Widget? accion;
  final String? subtitulo;

  const UsuarioCard({
    super.key,
    required this.usuario,
    this.onTap,
    this.accion,
    this.subtitulo,
  });

  @override
  Widget build(BuildContext context) {
    final username =
        usuario['username_usu'] ?? usuario['username'] ?? 'Usuario';
    final paisRaw = usuario['pais_usu'] ?? usuario['pais'];
    final pais = paisRaw != null ? PaisUtil.codigoANombre(paisRaw.toString()) : null;
    final reputacion = double.tryParse(
          usuario['repu_usu']?.toString() ?? usuario['repu']?.toString() ?? '0',
        ) ??
        0.0;

    return Material(
      color: SteamColors.bgPanel,
      borderRadius: BorderRadius.circular(SteamRadii.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(SteamRadii.sm),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(SteamRadii.sm),
            border: Border.all(color: SteamColors.border),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: SteamColors.blue.withOpacity(0.2),
                child: Text(
                  username.isNotEmpty ? username[0].toUpperCase() : '?',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: SteamColors.blue,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      username,
                      style: const TextStyle(
                        color: SteamColors.light,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    if (subtitulo != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitulo!,
                        style: const TextStyle(
                          color: SteamColors.textSec,
                          fontSize: 12,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (pais != null && pais != PaisUtil.todos) ...[
                          const Icon(Icons.public, size: 12, color: SteamColors.muted),
                          const SizedBox(width: 4),
                          Text(
                            pais,
                            style: const TextStyle(
                              fontSize: 11,
                              color: SteamColors.textSec,
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        const Icon(Icons.star_rounded, size: 12, color: SteamColors.green),
                        const SizedBox(width: 2),
                        Text(
                          reputacion.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 11,
                            color: SteamColors.green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (accion != null) accion!,
              if (onTap != null && accion == null)
                const Icon(Icons.chevron_right, color: SteamColors.muted, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
