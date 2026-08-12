import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uma_android/main.dart';

void main() {
  testWidgets('La aplicación muestra el acceso institucional', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const UmaApp());
    await tester.pumpAndSettle();

    expect(find.text('Registro diario\nde trabajos'), findsOneWidget);
    expect(find.text('INGRESAR'), findsOneWidget);
  });
}
