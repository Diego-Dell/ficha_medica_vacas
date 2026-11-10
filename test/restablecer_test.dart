import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ficha_medica_vacas/screens/acceso_general/restablecer_screen.dart';

import 'apoyo.dart';

void main() {
  setUp(prepararSesionPrueba);

  testWidgets('un enlace sin token muestra que no es válido', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: RestablecerScreen()));
    expect(find.text('Enlace no válido'), findsOneWidget);
    expect(
      find.text('Solicita otro correo para restablecer tu contraseña.'),
      findsOneWidget,
    );
  });

  testWidgets('el enlace con token permite cambiar la contraseña', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: RestablecerScreen(token: 'token-valido')),
    );
    await tester.enterText(find.byType(TextFormField).at(0), 'clave-nueva');
    await tester.enterText(find.byType(TextFormField).at(1), 'clave-nueva');
    await tester.ensureVisible(find.text('Guardar contraseña'));
    await tester.tap(find.text('Guardar contraseña'));
    await tester.pumpAndSettle();
    expect(find.text('Contraseña actualizada'), findsOneWidget);
    expect(find.text('Volver al inicio de sesión'), findsOneWidget);
  });
}
