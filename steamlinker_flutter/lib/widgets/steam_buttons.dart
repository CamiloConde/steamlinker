import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/radii.dart';

/// Botón primario (azul). [fullWidth] para formularios; [compact] para listas o filas estrechas.
class SteamButtonPrimary extends StatelessWidget {
  final String label;
  final IconData? icon;
  final void Function(BuildContext context)? onTap;
  final bool fullWidth;
  final bool compact;

  const SteamButtonPrimary({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.fullWidth = true,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final button = ElevatedButton(
      onPressed: onTap == null ? null : () => onTap!(context),
      style: ElevatedButton.styleFrom(
        backgroundColor: SteamColors.blue,
        foregroundColor: Colors.white,
        disabledBackgroundColor: SteamColors.bgCard,
        disabledForegroundColor: SteamColors.muted,
        elevation: 0,
        minimumSize: Size(compact ? 72 : 64, compact ? 36 : 44),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 16,
          vertical: compact ? 8 : 12,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SteamRadii.sm)),
      ),
      child: _ButtonLabel(label: label, icon: icon, compact: compact, onPrimary: true),
    );

    if (!fullWidth) return button;
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        if (!w.isFinite) return button;
        return SizedBox(width: w, child: button);
      },
    );
  }
}

/// Botón con borde azul.
class SteamButtonOutline extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool fullWidth;
  final bool compact;

  const SteamButtonOutline({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.fullWidth = true,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final button = OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: SteamColors.blue,
        disabledForegroundColor: SteamColors.muted,
        side: const BorderSide(color: SteamColors.blue),
        minimumSize: Size(compact ? 72 : 64, compact ? 36 : 44),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 16,
          vertical: compact ? 8 : 12,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SteamRadii.sm)),
      ),
      child: _ButtonLabel(label: label, icon: icon, compact: compact),
    );

    if (!fullWidth) return button;
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        if (!w.isFinite) return button;
        return SizedBox(width: w, child: button);
      },
    );
  }
}

/// Botón de acción destructiva.
class SteamButtonDanger extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool fullWidth;

  const SteamButtonDanger({
    super.key,
    required this.label,
    required this.icon,
    this.onTap,
    this.fullWidth = true,
  });

  @override
  Widget build(BuildContext context) {
    final button = OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: SteamColors.red,
        side: BorderSide(color: SteamColors.red.withValues(alpha: 0.6)),
        minimumSize: const Size(64, 44),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SteamRadii.sm)),
      ),
      child: _ButtonLabel(label: label, icon: icon, compact: false),
    );

    if (!fullWidth) return button;
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        if (!w.isFinite) return button;
        return SizedBox(width: w, child: button);
      },
    );
  }
}

class _ButtonLabel extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool compact;
  final bool onPrimary;

  const _ButtonLabel({
    required this.label,
    this.icon,
    required this.compact,
    this.onPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    final fg = onPrimary ? Colors.white : null;
    final textStyle = TextStyle(
      fontSize: compact ? 12 : 13,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.2,
      color: fg,
    );

    if (icon == null) {
      return Text(
        label,
        style: textStyle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: compact ? 16 : 18, color: fg),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            style: textStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
