import 'package:flutter/material.dart';
import 'legal_document_screen.dart';

class PoliticaPrivacidadScreen extends StatelessWidget {
  const PoliticaPrivacidadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const LegalDocumentScreen(
      titulo: 'PRIVACIDAD',
      actualizado: 'septiembre de 2026',
      secciones: [
        LegalSeccion(
          titulo: '1. Qué datos guardamos',
          cuerpo:
              'Al crear tu cuenta: tu nombre de usuario, correo, contraseña (nunca en '
              'texto plano — se guarda encriptada con bcrypt) y país. Opcionalmente '
              'puedes agregar una descripción de perfil. Si publicas, comentas, '
              'chateas o calificas a otro usuario, guardamos ese contenido para que la '
              'app funcione (encontrar compañeros, mostrar el historial de chat, '
              'calcular tu reputación).',
        ),
        LegalSeccion(
          titulo: '2. Si vinculas tu cuenta de Steam',
          cuerpo:
              'Solo si tú decides vincularla: guardamos tu Steam ID, tu nombre de '
              'usuario de Steam, tu avatar y la lista de juegos de tu biblioteca (con '
              'las horas jugadas), obtenidos de la API pública de Steam. Esto requiere '
              'que tu perfil de Steam sea público. Puedes desvincular tu cuenta de '
              'Steam en cualquier momento desde tu Perfil.',
        ),
        LegalSeccion(
          titulo: '3. Qué NO hacemos',
          cuerpo:
              'No usamos cookies. No tenemos herramientas de analítica ni publicidad '
              'de terceros integradas en la app. No vendemos ni compartimos tus datos '
              'con terceros para fines comerciales. Si donas a través de Ko-fi, esa '
              'transacción ocurre por completo en el sitio de Ko-fi — nosotros no '
              'vemos ni guardamos ningún dato de pago.',
        ),
        LegalSeccion(
          titulo: '4. Quién puede ver tu información',
          cuerpo:
              'Tu perfil, biblioteca y publicaciones son visibles para otros usuarios '
              'según lo que configures en Privacidad (dentro de Configuración): puedes '
              'ocultar tu perfil o tu biblioteca en cualquier momento. Los mensajes de '
              'chat solo los ve la otra persona de la conversación. Los reportes que '
              'hagas o recibas solo los revisa el equipo de moderación.',
        ),
        LegalSeccion(
          titulo: '5. Cómo se guarda',
          cuerpo:
              'Todo se guarda en una base de datos PostgreSQL. El inicio de sesión usa '
              'un token (JWT) que se guarda en tu dispositivo — no usamos cookies para '
              'esto. Las contraseñas se encriptan antes de guardarse; nadie, ni '
              'siquiera el equipo de SteamMatch, puede ver tu contraseña real.',
        ),
        LegalSeccion(
          titulo: '6. Tus derechos',
          cuerpo:
              'Puedes editar tu perfil, desvincular tu cuenta de Steam y eliminar tu '
              'cuenta por completo en cualquier momento desde Configuración → Zona de '
              'Peligro. Al eliminar tu cuenta se borran también tus publicaciones, '
              'mensajes, calificaciones y demás datos asociados. Si prefieres hacerlo '
              'por correo, o tienes cualquier pregunta sobre tus datos, escríbenos a '
              'camilandre0510@gmail.com.',
        ),
        LegalSeccion(
          titulo: '7. Marco legal',
          cuerpo:
              'Tratamos tus datos conforme a la Ley 1581 de 2012 de Colombia sobre '
              'protección de datos personales (Habeas Data).',
        ),
      ],
    );
  }
}
