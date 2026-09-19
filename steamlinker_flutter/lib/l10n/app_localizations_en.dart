// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTagline => 'Your gamer community connector';

  @override
  String get loginTitle => 'SIGN IN';

  @override
  String get registerTitle => 'CREATE ACCOUNT';

  @override
  String get usernameLabel => 'USERNAME';

  @override
  String get usernameHint => 'Your username';

  @override
  String get emailLabel => 'EMAIL';

  @override
  String get emailHint => 'you@email.com';

  @override
  String get passwordLabel => 'PASSWORD';

  @override
  String get loginButton => 'SIGN IN';

  @override
  String get steamLinkNote =>
      'Linking your Steam account is a later step, inside Profile. It\'s only needed to post or match in a Family.';

  @override
  String get legalConsentPrefix => 'By creating your account, you accept our ';

  @override
  String get legalConsentAnd => ' and our ';

  @override
  String get legalConsentSuffix => '.';

  @override
  String get legalNoticeLink => 'Legal Notice';

  @override
  String get privacyPolicyLink => 'Privacy Policy';

  @override
  String get haveAccountQuestion => 'Already have an account? ';

  @override
  String get noAccountQuestion => 'Don\'t have an account? ';

  @override
  String get signInLink => 'Sign in';

  @override
  String get signUpLink => 'Create free account';

  @override
  String get notAffiliated => 'Not affiliated with Valve Corporation';

  @override
  String get errorEmailRequired => 'Email is required';

  @override
  String get errorEmailInvalid => 'Email format is invalid';

  @override
  String get errorPasswordRequired => 'Password is required';

  @override
  String get errorPasswordTooShort => 'Password must be at least 4 characters';

  @override
  String get errorUsernameRequired => 'Username is required';

  @override
  String get errorUsernameTooShort => 'Username must be at least 3 characters';

  @override
  String get sessionStarted => 'Signed in successfully';

  @override
  String get navHome => 'Home';

  @override
  String get navDiscover => 'Discover';

  @override
  String get navPosts => 'Posts';

  @override
  String get navFriends => 'Friends';

  @override
  String get navChat => 'Chat';

  @override
  String get navAlerts => 'Alerts';

  @override
  String get navProfile => 'Profile';

  @override
  String get navPublicaciones => 'Posts';

  @override
  String get yourGamesSection => 'YOUR FAVORITES';

  @override
  String get noGamesYet => 'Mark games as favorites in your profile.';

  @override
  String get viewAllArrow => 'View all →';

  @override
  String get connectPromoTitle => 'Connect with other gamers';

  @override
  String get connectPromoBody =>
      'Find people with the same games and schedule as you.';

  @override
  String get exploreButton => 'Explore';

  @override
  String get defaultGameName => 'Game';

  @override
  String get languageSectionTitle => 'Language';

  @override
  String get languageSpanish => 'Español';

  @override
  String get languageEnglish => 'English';
}
