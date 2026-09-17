import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/radii.dart';

class SteamCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;
  final Color accent;

  const SteamCard({
    super.key,
    required this.icon,
    required this.title,
    required this.child,
    this.accent = SteamColors.blue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: SteamColors.bgCard,
        borderRadius: BorderRadius.circular(SteamRadii.sm),
        border: Border.all(color: SteamColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ─────────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.07),
              border: const Border(bottom: BorderSide(color: SteamColors.border)),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(6),
                topRight: Radius.circular(6),
              ),
            ),
            child: Row(children: [
              Icon(icon, size: 14, color: accent),
              const SizedBox(width: 8),
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  color: accent,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ]),
          ),

          // ── Body ───────────────────────────────────────────────────
          Padding(padding: const EdgeInsets.all(16), child: child),
        ],
      ),
    );
  }
}
