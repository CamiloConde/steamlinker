import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
  ];

  /// Subtítulo bajo el logo en la pantalla de login
  ///
  /// In es, this message translates to:
  /// **'Tu conector de comunidad gamer'**
  String get appTagline;

  /// No description provided for @loginTitle.
  ///
  /// In es, this message translates to:
  /// **'INICIAR SESIÓN'**
  String get loginTitle;

  /// No description provided for @registerTitle.
  ///
  /// In es, this message translates to:
  /// **'CREAR CUENTA'**
  String get registerTitle;

  /// No description provided for @usernameLabel.
  ///
  /// In es, this message translates to:
  /// **'NOMBRE DE USUARIO'**
  String get usernameLabel;

  /// No description provided for @usernameHint.
  ///
  /// In es, this message translates to:
  /// **'Tu nombre de usuario'**
  String get usernameHint;

  /// No description provided for @emailLabel.
  ///
  /// In es, this message translates to:
  /// **'CORREO'**
  String get emailLabel;

  /// No description provided for @emailHint.
  ///
  /// In es, this message translates to:
  /// **'tu@correo.com'**
  String get emailHint;

  /// No description provided for @passwordLabel.
  ///
  /// In es, this message translates to:
  /// **'CONTRASEÑA'**
  String get passwordLabel;

  /// No description provided for @loginButton.
  ///
  /// In es, this message translates to:
  /// **'INGRESAR'**
  String get loginButton;

  /// No description provided for @steamLinkNote.
  ///
  /// In es, this message translates to:
  /// **'Vincular tu cuenta de Steam es un paso posterior, dentro de Perfil. Hace falta solo para publicar o matchear en Familia.'**
  String get steamLinkNote;

  /// No description provided for @legalConsentPrefix.
  ///
  /// In es, this message translates to:
  /// **'Al crear tu cuenta, aceptas nuestro '**
  String get legalConsentPrefix;

  /// No description provided for @legalConsentAnd.
  ///
  /// In es, this message translates to:
  /// **' y nuestra '**
  String get legalConsentAnd;

  /// No description provided for @legalConsentSuffix.
  ///
  /// In es, this message translates to:
  /// **'.'**
  String get legalConsentSuffix;

  /// No description provided for @legalNoticeLink.
  ///
  /// In es, this message translates to:
  /// **'Aviso legal'**
  String get legalNoticeLink;

  /// No description provided for @privacyPolicyLink.
  ///
  /// In es, this message translates to:
  /// **'Política de privacidad'**
  String get privacyPolicyLink;

  /// No description provided for @haveAccountQuestion.
  ///
  /// In es, this message translates to:
  /// **'¿Ya tienes cuenta? '**
  String get haveAccountQuestion;

  /// No description provided for @noAccountQuestion.
  ///
  /// In es, this message translates to:
  /// **'¿No tienes cuenta? '**
  String get noAccountQuestion;

  /// No description provided for @signInLink.
  ///
  /// In es, this message translates to:
  /// **'Inicia sesión'**
  String get signInLink;

  /// No description provided for @signUpLink.
  ///
  /// In es, this message translates to:
  /// **'Crear cuenta gratis'**
  String get signUpLink;

  /// No description provided for @notAffiliated.
  ///
  /// In es, this message translates to:
  /// **'No afiliado a Valve Corporation'**
  String get notAffiliated;

  /// No description provided for @errorEmailRequired.
  ///
  /// In es, this message translates to:
  /// **'El correo es obligatorio'**
  String get errorEmailRequired;

  /// No description provided for @errorEmailInvalid.
  ///
  /// In es, this message translates to:
  /// **'El correo no tiene un formato válido'**
  String get errorEmailInvalid;

  /// No description provided for @errorPasswordRequired.
  ///
  /// In es, this message translates to:
  /// **'La contraseña es obligatoria'**
  String get errorPasswordRequired;

  /// No description provided for @errorPasswordTooShort.
  ///
  /// In es, this message translates to:
  /// **'La contraseña debe tener al menos 4 caracteres'**
  String get errorPasswordTooShort;

  /// No description provided for @errorUsernameRequired.
  ///
  /// In es, this message translates to:
  /// **'El nombre de usuario es obligatorio'**
  String get errorUsernameRequired;

  /// No description provided for @errorUsernameTooShort.
  ///
  /// In es, this message translates to:
  /// **'El usuario debe tener al menos 3 caracteres'**
  String get errorUsernameTooShort;

  /// No description provided for @sessionStarted.
  ///
  /// In es, this message translates to:
  /// **'Sesión iniciada correctamente'**
  String get sessionStarted;

  /// No description provided for @navHome.
  ///
  /// In es, this message translates to:
  /// **'Inicio'**
  String get navHome;

  /// No description provided for @navDiscover.
  ///
  /// In es, this message translates to:
  /// **'Descubrir'**
  String get navDiscover;

  /// No description provided for @navPosts.
  ///
  /// In es, this message translates to:
  /// **'Publica.'**
  String get navPosts;

  /// No description provided for @navFriends.
  ///
  /// In es, this message translates to:
  /// **'Amigos'**
  String get navFriends;

  /// No description provided for @navChat.
  ///
  /// In es, this message translates to:
  /// **'Chat'**
  String get navChat;

  /// No description provided for @navAlerts.
  ///
  /// In es, this message translates to:
  /// **'Avisos'**
  String get navAlerts;

  /// No description provided for @navProfile.
  ///
  /// In es, this message translates to:
  /// **'Perfil'**
  String get navProfile;

  /// No description provided for @navPublicaciones.
  ///
  /// In es, this message translates to:
  /// **'Publicaciones'**
  String get navPublicaciones;

  /// No description provided for @yourGamesSection.
  ///
  /// In es, this message translates to:
  /// **'TUS JUEGOS'**
  String get yourGamesSection;

  /// No description provided for @noGamesYet.
  ///
  /// In es, this message translates to:
  /// **'Aún no agregas juegos.'**
  String get noGamesYet;

  /// No description provided for @viewAllArrow.
  ///
  /// In es, this message translates to:
  /// **'Ver todos →'**
  String get viewAllArrow;

  /// No description provided for @connectPromoTitle.
  ///
  /// In es, this message translates to:
  /// **'Conecta con otros gamers'**
  String get connectPromoTitle;

  /// No description provided for @connectPromoBody.
  ///
  /// In es, this message translates to:
  /// **'Encuentra personas con los mismos juegos y horarios que tú.'**
  String get connectPromoBody;

  /// No description provided for @exploreButton.
  ///
  /// In es, this message translates to:
  /// **'Explorar'**
  String get exploreButton;

  /// No description provided for @defaultGameName.
  ///
  /// In es, this message translates to:
  /// **'Juego'**
  String get defaultGameName;

  /// No description provided for @languageSectionTitle.
  ///
  /// In es, this message translates to:
  /// **'Idioma'**
  String get languageSectionTitle;

  /// No description provided for @languageSpanish.
  ///
  /// In es, this message translates to:
  /// **'Español'**
  String get languageSpanish;

  /// No description provided for @languageEnglish.
  ///
  /// In es, this message translates to:
  /// **'English'**
  String get languageEnglish;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
