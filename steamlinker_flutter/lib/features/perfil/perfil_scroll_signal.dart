import 'package:flutter/foundation.dart';

/// Señal simple para pedirle a la pantalla de Perfil (que el IndexedStack
/// del shell mantiene viva sin reconstruir al cambiar de pestaña) que se
/// desplace a la sección de Juegos — la usa "Ver todos →" en el sidebar de
/// escritorio, para no aterrizar arriba del todo y obligar a bajar a mano.
class PerfilScrollSignal extends ChangeNotifier {
  void pedirScrollAJuegos() => notifyListeners();
}

final perfilScrollSignal = PerfilScrollSignal();
