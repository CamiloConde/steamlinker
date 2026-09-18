import 'package:flutter/material.dart';

/// Señal compartida para el único botón de refrescar de la barra superior
/// de escritorio: cada pantalla vive dentro de un IndexedStack (todas
/// montadas a la vez), así que no basta con "notificar a quien esté
/// escuchando" -- hay que decirle a CUÁL pantalla refrescar, si no todas
/// refrescarían sus datos a la vez aunque solo una esté visible. Mismo
/// patrón que PerfilScrollSignal (ver perfil_scroll_signal.dart).
class RefreshSignal extends ChangeNotifier {
  int _indice = -1;
  int get indice => _indice;

  void pedirRefresh(int indicePantallaActiva) {
    _indice = indicePantallaActiva;
    notifyListeners();
  }
}

final refreshSignal = RefreshSignal();
