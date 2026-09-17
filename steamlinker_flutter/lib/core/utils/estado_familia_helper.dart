/// Deriva el estado de familia de un usuario a partir de datos que ya
/// existen (no hay tabla/rol de membresía formal en el backend — ver
/// HANDOFF.md). Usado en Inicio y Perfil para no duplicar la heurística:
/// - "Buscando familia" si tiene una publicación propia y abierta de tipo
///   busco_familia/busco_miembros (con cupos si el backend los trae).
/// - "En una familia" si tiene un match Aceptado (enviado por él) hacia una
///   publicación de ese tipo que sigue abierta.
/// - "Sin familia" en cualquier otro caso.
///
/// Limitación conocida: una familia que ya se llenó y se autocerró no se
/// detecta, porque el match sigue existiendo pero la publicación ya no
/// aparece en la lista para cruzarla.
class EstadoFamilia {
  final String etiqueta;
  final int? ocupados;
  final int? total;

  const EstadoFamilia({required this.etiqueta, this.ocupados, this.total});
}

Map<String, dynamic>? buscarPublicacionPorId(List<dynamic> lista, dynamic id) {
  for (final p in lista) {
    if (p is Map && p['id_publi'] == id) return Map<String, dynamic>.from(p);
  }
  return null;
}

bool esTipoFamilia(String? tipo) => tipo == 'busco_familia' || tipo == 'busco_miembros';

EstadoFamilia calcularEstadoFamilia({
  required List<dynamic> misPublicaciones,
  required List<dynamic> matchesEnviados,
  required List<dynamic> todasPublicaciones,
}) {
  for (final p in misPublicaciones) {
    final map = Map<String, dynamic>.from(p as Map);
    if (esTipoFamilia(map['tipo_publi'] as String?)) {
      return EstadoFamilia(
        etiqueta: 'Buscando familia',
        ocupados: map['cupos_ocupados'] as int?,
        total: map['cupos_totales'] as int?,
      );
    }
  }

  final enFamiliaAjena = matchesEnviados.any((m) {
    if (m['estado_match'] != 'Aceptada') return false;
    final pub = buscarPublicacionPorId(todasPublicaciones, m['id_publi']);
    return pub != null && esTipoFamilia(pub['tipo_publi'] as String?);
  });
  if (enFamiliaAjena) return const EstadoFamilia(etiqueta: 'En una familia');

  return const EstadoFamilia(etiqueta: 'Sin familia');
}
