import '../constants/publicacion_constants.dart';

/// Deriva el estado de familia de un usuario a partir de datos que ya
/// existen (no hay tabla/rol de membresía formal en el backend — ver
/// HANDOFF.md). Usado en Inicio y Perfil para no duplicar la heurística:
/// - "Busco familia" o "Busco miembros" (el texto EXACTO de tu propia
///   publicación, ver `PublicacionConstants.etiquetaTipo`) si tienes una
///   publicación propia y abierta de alguno de esos dos tipos -- antes
///   ambos casos mostraban el mismo "Buscando familia" genérico, lo cual
///   es literalmente lo contrario para busco_miembros (ya tienes gente/
///   cupos y estás reclutando, no buscando una familia para unirte). El
///   usuario lo notó probando: ya tiene familia real en Steam y una
///   publicación de tipo busco_miembros, pero veía "Buscando familia".
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
    final tipo = map['tipo_publi'] as String?;
    if (esTipoFamilia(tipo)) {
      return EstadoFamilia(
        etiqueta: PublicacionConstants.etiquetaTipo(tipo),
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
