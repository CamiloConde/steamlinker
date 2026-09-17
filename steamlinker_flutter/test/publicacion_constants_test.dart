// Cubre el gateo de Steam de la Fase 2 en el lado Flutter (ver
// HANDOFF.md seccion 5 y 9): Familia lo requiere, Companeros no.
import 'package:flutter_test/flutter_test.dart';
import 'package:steamlinker_flutter/core/constants/publicacion_constants.dart';

void main() {
  group('PublicacionConstants.requiereSteam', () {
    test('busco_familia requiere Steam vinculado', () {
      expect(PublicacionConstants.requiereSteam('busco_familia'), isTrue);
    });

    test('busco_miembros requiere Steam vinculado', () {
      expect(PublicacionConstants.requiereSteam('busco_miembros'), isTrue);
    });

    test('busco_companero NO requiere Steam vinculado', () {
      expect(PublicacionConstants.requiereSteam('busco_companero'), isFalse);
    });

    test('otro NO requiere Steam vinculado', () {
      expect(PublicacionConstants.requiereSteam('otro'), isFalse);
    });
  });

  group('PublicacionConstants listas de tipos', () {
    test('tiposCrearEtiquetas y tiposCrearValores tienen la misma longitud', () {
      expect(
        PublicacionConstants.tiposCrearEtiquetas.length,
        PublicacionConstants.tiposCrearValores.length,
      );
    });

    test('tiposFiltroEtiquetas y tiposFiltroValores tienen la misma longitud', () {
      expect(
        PublicacionConstants.tiposFiltroEtiquetas.length,
        PublicacionConstants.tiposFiltroValores.length,
      );
    });

    test('valorTipoCrear resuelve la etiqueta a su valor correcto', () {
      expect(PublicacionConstants.valorTipoCrear('Busco familia'), 'busco_familia');
      expect(
        PublicacionConstants.valorTipoCrear('Busco compañero de juego'),
        'busco_companero',
      );
    });

    test('valorTipoCrear con etiqueta desconocida cae a "otro"', () {
      expect(PublicacionConstants.valorTipoCrear('no existe'), 'otro');
    });

    test('etiquetaTipo(null) devuelve "General"', () {
      expect(PublicacionConstants.etiquetaTipo(null), 'General');
    });
  });
}
