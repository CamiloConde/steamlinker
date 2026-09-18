import 'package:flutter/material.dart';
import 'legal_document_screen.dart';

class AvisoLegalScreen extends StatelessWidget {
  const AvisoLegalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const LegalDocumentScreen(
      titulo: 'AVISO LEGAL',
      actualizado: 'septiembre de 2026',
      secciones: [
        LegalSeccion(
          titulo: '1. Qué es SteamMatch',
          cuerpo:
              'SteamMatch es un proyecto independiente, en etapa de beta, que conecta '
              'jugadores según los videojuegos que ya tienen en su biblioteca. No es un '
              'producto de Valve Corporation ni está afiliado, patrocinado o respaldado '
              'por Valve, Steam, ni ninguna otra marca mencionada dentro de la app '
              '(los nombres e imágenes de juegos y plataformas pertenecen a sus '
              'respectivos dueños y se usan solo con fines descriptivos).',
        ),
        LegalSeccion(
          titulo: '2. Quién lo opera',
          cuerpo:
              'SteamMatch es operado de forma independiente, sin una entidad legal '
              'registrada. Para consultas, reportes o solicitudes relacionadas con este '
              'aviso legal o con tus datos, puedes escribir a camilandre0510@gmail.com.',
        ),
        LegalSeccion(
          titulo: '3. Edad mínima',
          cuerpo:
              'Para crear una cuenta debes tener al menos 13 años. Si detectamos una '
              'cuenta que no cumple este requisito, podemos suspenderla.',
        ),
        LegalSeccion(
          titulo: '4. Tu contenido y tu conducta',
          cuerpo:
              'Eres responsable de lo que publiques: tu descripción de perfil, tus '
              'publicaciones buscando compañeros de juego, los comentarios y los '
              'mensajes de chat. No está permitido el acoso, las amenazas, la '
              'suplantación de identidad, el contenido ilegal, el spam ni el uso de la '
              'plataforma para fines distintos a conectar jugadores. Las cuentas '
              'reportadas se revisan manualmente y pueden ser suspendidas o eliminadas '
              'si se confirma una infracción.',
        ),
        LegalSeccion(
          titulo: '5. Vinculación con Steam',
          cuerpo:
              'Vincular tu cuenta de Steam es opcional y solo se pide cuando de verdad '
              'lo necesitas (publicar buscando compañeros o participar en un match de '
              'Familia). Al vincularla, algunos datos públicos de tu perfil de Steam '
              '(como tu biblioteca de juegos, si tu perfil es público) se usan dentro de '
              'la app — ver la Política de Privacidad para el detalle completo.',
        ),
        LegalSeccion(
          titulo: '6. Servicio en etapa beta',
          cuerpo:
              'SteamMatch está en desarrollo activo. Funciones pueden cambiar, '
              'agregarse o eliminarse sin aviso previo mientras dure esta etapa, y no '
              'garantizamos disponibilidad ininterrumpida del servicio.',
        ),
        LegalSeccion(
          titulo: '7. Ley aplicable',
          cuerpo:
              'Este aviso se rige por las leyes de Colombia, incluyendo lo dispuesto en '
              'la Ley 1581 de 2012 sobre protección de datos personales.',
        ),
      ],
    );
  }
}
