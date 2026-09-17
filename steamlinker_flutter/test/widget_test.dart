import 'package:flutter_test/flutter_test.dart';
import 'package:steamlinker_flutter/main.dart';
import 'package:steamlinker_flutter/core/network/api_client.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    ApiClient.init();
  });

  testWidgets('Muestra pantalla de login', (WidgetTester tester) async {
    await tester.pumpWidget(const SteamlinkerApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('INICIAR SESIÓN'), findsOneWidget);
    expect(find.text('Servidor'), findsOneWidget);
  });
}
