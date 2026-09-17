class PublicacionConstants {
  PublicacionConstants._();

  static const ordenRecientes = 'recientes';
  static const ordenReputacion = 'reputacion';

  static const Map<String, String> tipoEtiquetas = {
    'busco_familia': 'Busco familia',
    'busco_miembros': 'Busco miembros',
    'busco_companero': 'Busco compañero de juego',
    'otro': 'Otro',
  };

  // Tipos que exigen tener Steam vinculado para publicar/matchear (ver
  // HANDOFF.md seccion 5: compartir biblioteca es de alto riesgo si el
  // usuario no es quien dice ser; jugar juntos no lo es).
  static const List<String> tiposRequierenSteam = [
    'busco_familia',
    'busco_miembros',
  ];

  static bool requiereSteam(String tipo) => tiposRequierenSteam.contains(tipo);

  static const List<String> tiposCrearEtiquetas = [
    'Busco familia',
    'Busco miembros',
    'Busco compañero de juego',
    'Otro',
  ];

  static const List<String> tiposCrearValores = [
    'busco_familia',
    'busco_miembros',
    'busco_companero',
    'otro',
  ];

  static const List<String> tiposFiltroEtiquetas = [
    'Todos los tipos',
    'Busco familia',
    'Busco miembros',
    'Busco compañero de juego',
    'Otro',
  ];

  static const List<String> tiposFiltroValores = [
    '',
    'busco_familia',
    'busco_miembros',
    'busco_companero',
    'otro',
  ];

  static String etiquetaTipo(String? tipo) {
    if (tipo == null || tipo.isEmpty) return 'General';
    if (tipo.contains(',')) {
      return tipo.split(',').map((t) => tipoEtiquetas[t] ?? t).join(' / ');
    }
    return tipoEtiquetas[tipo] ?? tipo;
  }

  static String valorTipoCrear(String etiqueta) {
    final i = tiposCrearEtiquetas.indexOf(etiqueta);
    return i >= 0 ? tiposCrearValores[i] : 'otro';
  }

  static String valorTipoFiltro(String etiqueta) {
    final i = tiposFiltroEtiquetas.indexOf(etiqueta);
    return i >= 0 ? tiposFiltroValores[i] : '';
  }
}
