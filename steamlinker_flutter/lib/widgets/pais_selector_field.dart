import 'package:flutter/material.dart';
import '../core/constants/pais_util.dart';
import '../theme/colors.dart';
import '../theme/radii.dart';

/// Selector de país con buscador.
///
/// Con la lista ampliada de países (ver PaisUtil) un dropdown plano
/// obligaba a desplazarse uno por uno para encontrar el país -- pedido
/// explícito del usuario de simplificar eso. Se ve como un DropField pero
/// al tocarlo abre una hoja con un buscador arriba.
class PaisSelectorField extends StatelessWidget {
  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String>? onChanged;

  const PaisSelectorField({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    this.onChanged,
  });

  Future<void> _abrirSelector(BuildContext context) async {
    final seleccionado = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: SteamColors.bgPanel,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (_) => _PaisBuscadorSheet(items: items, seleccionado: value),
    );
    if (seleccionado != null && onChanged != null) {
      onChanged!(seleccionado);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    final activo = onChanged != null;
    final seleccionado = items.contains(value) ? value : items.first;

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
        InkWell(
          onTap: activo ? () => _abrirSelector(context) : null,
          borderRadius: BorderRadius.circular(SteamRadii.sm),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: SteamColors.bgInput,
              borderRadius: BorderRadius.circular(SteamRadii.sm),
              border: Border.all(color: SteamColors.border),
            ),
            child: Row(
              children: [
                if (seleccionado != PaisUtil.todos) ...[
                  Text(
                    PaisUtil.codigoABandera(
                          PaisUtil.nombreACodigo(seleccionado),
                        ) ??
                        '',
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(
                    seleccionado,
                    style: const TextStyle(
                      color: SteamColors.light,
                      fontSize: 13,
                    ),
                  ),
                ),
                Icon(
                  Icons.expand_more,
                  color: activo
                      ? SteamColors.muted
                      : SteamColors.muted.withValues(alpha: 0.4),
                  size: 18,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _PaisBuscadorSheet extends StatefulWidget {
  final List<String> items;
  final String seleccionado;

  const _PaisBuscadorSheet({required this.items, required this.seleccionado});

  @override
  State<_PaisBuscadorSheet> createState() => _PaisBuscadorSheetState();
}

class _PaisBuscadorSheetState extends State<_PaisBuscadorSheet> {
  final _controller = TextEditingController();
  late List<String> _filtrados = widget.items;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _filtrar(String texto) {
    final q = texto.trim().toLowerCase();
    setState(() {
      _filtrados = q.isEmpty
          ? widget.items
          : widget.items.where((p) => p.toLowerCase().contains(q)).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: SteamColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: _controller,
                autofocus: true,
                onChanged: _filtrar,
                style: const TextStyle(color: SteamColors.light, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Buscar país...',
                  hintStyle: const TextStyle(color: SteamColors.muted),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: SteamColors.muted,
                    size: 20,
                  ),
                  filled: true,
                  fillColor: SteamColors.bgInput,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(SteamRadii.sm),
                    borderSide: const BorderSide(color: SteamColors.border),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            Flexible(
              child: _filtrados.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Sin resultados',
                        style: TextStyle(color: SteamColors.textSec),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _filtrados.length,
                      itemBuilder: (context, i) {
                        final pais = _filtrados[i];
                        final activo = pais == widget.seleccionado;
                        final bandera = pais == PaisUtil.todos
                            ? null
                            : PaisUtil.codigoABandera(
                                PaisUtil.nombreACodigo(pais),
                              );
                        return ListTile(
                          leading: bandera == null
                              ? null
                              : Text(
                                  bandera,
                                  style: const TextStyle(fontSize: 16),
                                ),
                          title: Text(
                            pais,
                            style: TextStyle(
                              color: activo
                                  ? SteamColors.blue
                                  : SteamColors.light,
                              fontWeight: activo
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                              fontSize: 13.5,
                            ),
                          ),
                          trailing: activo
                              ? const Icon(
                                  Icons.check,
                                  color: SteamColors.blue,
                                  size: 18,
                                )
                              : null,
                          onTap: () => Navigator.pop(context, pais),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
