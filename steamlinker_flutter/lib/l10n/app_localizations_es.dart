// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTagline => 'Tu conector de comunidad gamer';

  @override
  String get loginTitle => 'INICIAR SESIÓN';

  @override
  String get registerTitle => 'CREAR CUENTA';

  @override
  String get usernameLabel => 'NOMBRE DE USUARIO';

  @override
  String get usernameHint => 'Tu nombre de usuario';

  @override
  String get emailLabel => 'CORREO';

  @override
  String get emailHint => 'tu@correo.com';

  @override
  String get passwordLabel => 'CONTRASEÑA';

  @override
  String get loginButton => 'INGRESAR';

  @override
  String get steamLinkNote =>
      'Vincular tu cuenta de Steam es un paso posterior, dentro de Perfil. Hace falta solo para publicar o matchear en Familia.';

  @override
  String get legalConsentPrefix => 'Al crear tu cuenta, aceptas nuestro ';

  @override
  String get legalConsentAnd => ' y nuestra ';

  @override
  String get legalConsentSuffix => '.';

  @override
  String get legalNoticeLink => 'Aviso legal';

  @override
  String get privacyPolicyLink => 'Política de privacidad';

  @override
  String get haveAccountQuestion => '¿Ya tienes cuenta? ';

  @override
  String get noAccountQuestion => '¿No tienes cuenta? ';

  @override
  String get signInLink => 'Inicia sesión';

  @override
  String get signUpLink => 'Crear cuenta gratis';

  @override
  String get notAffiliated => 'No afiliado a Valve Corporation';

  @override
  String get errorEmailRequired => 'El correo es obligatorio';

  @override
  String get errorEmailInvalid => 'El correo no tiene un formato válido';

  @override
  String get errorPasswordRequired => 'La contraseña es obligatoria';

  @override
  String get errorPasswordTooShort =>
      'La contraseña debe tener al menos 4 caracteres';

  @override
  String get errorUsernameRequired => 'El nombre de usuario es obligatorio';

  @override
  String get errorUsernameTooShort =>
      'El usuario debe tener al menos 3 caracteres';

  @override
  String get sessionStarted => 'Sesión iniciada correctamente';

  @override
  String get navHome => 'Inicio';

  @override
  String get navDiscover => 'Descubrir';

  @override
  String get navPosts => 'Publica.';

  @override
  String get navFriends => 'Amigos';

  @override
  String get navChat => 'Chat';

  @override
  String get navAlerts => 'Avisos';

  @override
  String get navProfile => 'Perfil';

  @override
  String get navPublicaciones => 'Publicaciones';

  @override
  String get yourGamesSection => 'TUS JUEGOS';

  @override
  String get noGamesYet => 'Aún no agregas juegos.';

  @override
  String get viewAllArrow => 'Ver todos →';

  @override
  String get connectPromoTitle => 'Conecta con otros gamers';

  @override
  String get connectPromoBody =>
      'Encuentra personas con los mismos juegos y horarios que tú.';

  @override
  String get exploreButton => 'Explorar';

  @override
  String get defaultGameName => 'Juego';

  @override
  String get languageSectionTitle => 'Idioma';

  @override
  String get languageSpanish => 'Español';

  @override
  String get languageEnglish => 'English';
}
