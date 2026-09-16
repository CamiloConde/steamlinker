import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/radii.dart';

enum FieldState { idle, valid, invalid }

class ValidatedField extends StatefulWidget {
  final String label;
  final String placeholder;
  final String? initialValue;
  final bool obscure;
  final TextInputType keyboardType;
  final String? Function(String) validator;
  final void Function(String value, bool isValid)? onChanged;
  final Widget? extra; // widget extra debajo del input (ej: barra de fortaleza)

  const ValidatedField({
    super.key,
    required this.label,
    required this.placeholder,
    required this.validator,
    this.initialValue,
    this.obscure = false,
    this.keyboardType = TextInputType.text,
    this.onChanged,
    this.extra,
  });

  @override
  State<ValidatedField> createState() => _ValidatedFieldState();
}

class _ValidatedFieldState extends State<ValidatedField> {
  late final TextEditingController _ctrl;
  FieldState _state = FieldState.idle;
  String _msg = '';
  bool _showPassword = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialValue ?? '');
    if (widget.initialValue?.isNotEmpty == true) {
      _validate(widget.initialValue!);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _validate(String v) {
    if (v.isEmpty) {
      setState(() {
        _state = FieldState.idle;
        _msg = '';
      });
      widget.onChanged?.call(v, false);
      return;
    }
    final err = widget.validator(v);
    setState(() {
      _state = err == null ? FieldState.valid : FieldState.invalid;
      _msg = err ?? '';
    });
    widget.onChanged?.call(v, err == null);
  }

  // ── Colores según estado ──────────────────────────────────────────────
  Color get _borderColor => switch (_state) {
        FieldState.valid   => SteamColors.green,
        FieldState.invalid => SteamColors.red,
        FieldState.idle    => SteamColors.border,
      };

  Color get _msgColor => switch (_state) {
        FieldState.valid   => SteamColors.green,
        FieldState.invalid => SteamColors.red,
        FieldState.idle    => SteamColors.textSec,
      };

  // ── Ícono sufijo ─────────────────────────────────────────────────────
  Widget? get _suffixIcon {
    if (widget.obscure) {
      return GestureDetector(
        onTap: () => setState(() => _showPassword = !_showPassword),
        child: Icon(
          _showPassword
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
          color: SteamColors.muted,
          size: 18,
        ),
      );
    }
    return switch (_state) {
      FieldState.valid   => const Icon(Icons.check_rounded,  color: SteamColors.green, size: 18),
      FieldState.invalid => const Icon(Icons.close_rounded,  color: SteamColors.red,   size: 18),
      FieldState.idle    => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Label ──────────────────────────────────────────────────────
        Text(
          widget.label.toUpperCase(),
          style: const TextStyle(
            color: SteamColors.textSec,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 6),

        // ── Input ──────────────────────────────────────────────────────
        TextField(
          controller: _ctrl,
          obscureText: widget.obscure && !_showPassword,
          keyboardType: widget.keyboardType,
          onChanged: _validate,
          cursorColor: SteamColors.blue,
          style: const TextStyle(color: SteamColors.light, fontSize: 13),
          decoration: InputDecoration(
            hintText: widget.placeholder,
            hintStyle: TextStyle(
              color: SteamColors.textSec.withOpacity(0.5),
              fontSize: 13,
            ),
            filled: true,
            fillColor: SteamColors.bgInput,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(SteamRadii.sm),
              borderSide: BorderSide(color: _borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(SteamRadii.sm),
              borderSide: BorderSide(
                color: _state == FieldState.idle
                    ? SteamColors.blue
                    : _borderColor,
                width: 1.5,
              ),
            ),
            suffixIcon: _suffixIcon == null
                ? null
                : Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: _suffixIcon,
                  ),
            suffixIconConstraints:
                const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ),

        // ── Widget extra (ej: barra de fortaleza) ──────────────────────
        if (widget.extra != null) ...[
          const SizedBox(height: 4),
          widget.extra!,
        ],

        // ── Mensaje de validación ──────────────────────────────────────
        if (_msg.isNotEmpty) ...[
          const SizedBox(height: 4),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: Align(
              key: ValueKey(_msg),
              alignment: Alignment.centerLeft,
              child: Text(
                _msg,
                style: TextStyle(color: _msgColor, fontSize: 11),
              ),
            ),
          ),
        ],

        const SizedBox(height: 12),
      ],
    );
  }
}
