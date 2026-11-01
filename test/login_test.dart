import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ficha_medica_vacas/logic/sesion.dart';
import 'package:ficha_medica_vacas/main.dart';

void main() {
  test('Sesion siempre devuelve la misma instancia', () {
    expect(identical(Sesion.instance, Sesion.instance), isTrue);
  });

  // El Singleton conserva su estado entre pruebas: las credenciales correctas van al final.
  testWidgets('pide completar los campos', (tester) async {
    await tester.pumpWidget(const FichaMedicaApp());
    await tester.tap(find.text('Ingresar'));
    await tester.pump();
    expect(find.text('Campo obligatorio'), findsNWidgets(2));
  });

  testWidgets('rechaza credenciales incorrectas', (tester) async {
    await tester.pumpWidget(const FichaMedicaApp());
    await tester.enterText(find.byType(TextFormField).at(0), 'admin');
    await tester.enterText(find.byType(TextFormField).at(1), 'otra');
    await tester.tap(find.text('Ingresar'));
    await tester.pump();
    expect(find.text('Usuario o contraseña incorrectos'), findsOneWidget);
    expect(Sesion.instance.iniciada, isFalse);
  });

  testWidgets('inicia sesión con credenciales correctas', (tester) async {
    await tester.pumpWidget(const FichaMedicaApp());
    await tester.enterText(find.byType(TextFormField).at(0), ' admin ');
    await tester.enterText(find.byType(TextFormField).at(1), 'admin123');
    await tester.tap(find.widgetWithText(FilledButton, 'Ingresar'));
    await tester.pump();
    expect(find.text('Bienvenido, admin'), findsOneWidget);
    expect(Sesion.instance.iniciada, isTrue);
  });
}
