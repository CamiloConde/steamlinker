import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/radii.dart';

class StrengthBar extends StatelessWidget {
  final String password;

  const StrengthBar({super.key, required this.password});

  int get _score {
    if (password.isEmpty) return 0;
    int s = 0;
    if (password.length >= 8)                             s++;
    if (password.length >= 12)                            s++;
    if (RegExp(r'[A-Z]').hasMatch(password))              s++;
    if (RegExp(r'[0-9]').hasMatch(password))              s++;
    if (RegExp(r'[^a-zA-Z0-9]').hasMatch(password))      s++;
    return s;
  }

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) return const SizedBox();

    final pct = (_score / 5).clamp(0.0, 1.0);
    final color = pct < 0.4
        ? SteamColors.red
        : pct < 0.7
            ? SteamColors.yellow
            : SteamColors.green;
    const labels = ['', 'Muy débil', 'Débil', 'Aceptable', 'Fuerte', 'Muy fuerte'];
    final label = labels[_score.clamp(0, 5)];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(SteamRadii.sm),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: pct),
            duration: const Duration(milliseconds: 350),
            builder: (_, v, _) => LinearProgressIndicator(
              value: v,
              minHeight: 3,
              backgroundColor: SteamColors.border,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
        const SizedBox(height: 3),
        Text(label, style: TextStyle(color: color, fontSize: 10.5)),
      ],
    );
  }
}
