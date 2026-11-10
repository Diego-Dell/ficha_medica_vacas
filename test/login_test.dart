import 'package:flutter_test/flutter_test.dart';
import 'package:ficha_medica_vacas/main.dart';

import 'apoyo.dart';

void main() {
  setUp(prepararSesionPrueba);

  testWidgets('muestra la pantalla de inicio de sesión', (tester) async {
    await tester.pumpWidget(const FichaMedicaApp());

    expect(find.text('Bienvenido a VetLink'), findsOneWidget);
    expect(find.text('Correo electrónico'), findsOneWidget);
    expect(find.text('Contraseña'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsOneWidget);
  });

  testWidgets('valida los campos obligatorios del inicio de sesión', (
    tester,
  ) async {
    await tester.pumpWidget(const FichaMedicaApp());
    await tester.ensureVisible(find.text('Iniciar sesión'));
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();

    expect(find.text('Campo obligatorio'), findsNWidgets(2));
  });

  testWidgets('abre la pantalla para recuperar contraseña', (tester) async {
    await tester.pumpWidget(const FichaMedicaApp());
    await tester.ensureVisible(find.text('Olvidé mi contraseña'));
    await tester.tap(find.text('Olvidé mi contraseña'));
    await tester.pumpAndSettle();

    expect(find.text('Recuperar contraseña'), findsOneWidget);
    expect(find.text('Enviar enlace'), findsOneWidget);
  });
}
