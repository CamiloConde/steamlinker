import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/radii.dart';

/// Selector simple (estable en Flutter web; evita FormField + initialValue).
class DropField extends StatelessWidget {
  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String>? onChanged;

  const DropField({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    final selected = items.contains(value) ? value : items.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: SteamColors.textSec,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: SteamColors.bgInput,
            borderRadius: BorderRadius.circular(SteamRadii.sm),
            border: Border.all(color: SteamColors.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selected,
              isExpanded: true,
              dropdownColor: SteamColors.bgPanel,
              icon: const Icon(Icons.expand_more, color: SteamColors.muted, size: 18),
              style: const TextStyle(color: SteamColors.light, fontSize: 13),
              items: items
                  .map(
                    (e) => DropdownMenuItem(
                      value: e,
                      child: Text(
                        e,
                        style: const TextStyle(
                          color: SteamColors.light,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: onChanged == null
                  ? null
                  : (v) {
                      if (v != null) onChanged!(v);
                    },
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}
