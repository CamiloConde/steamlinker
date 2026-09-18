// Maneja el idioma elegido por el usuario (español/inglés) y lo persiste
// en el dispositivo. Español es el idioma por defecto si no hay nada
// guardado — coincide con el idioma en el que está escrita toda la app.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleProvider extends ChangeNotifier {
  static const _prefsKey = 'locale_code';

  Locale _locale = const Locale('es');

  Locale get locale => _locale;

  Future<void> cargar() async {
    final prefs = await SharedPreferences.getInstance();
    final guardado = prefs.getString(_prefsKey);
    if (guardado == 'en') {
      _locale = const Locale('en');
      notifyListeners();
    }
  }

  Future<void> cambiarA(String codigo) async {
    if (_locale.languageCode == codigo) return;
    _locale = Locale(codigo);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, codigo);
  }
}
