import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ficha_medica_vacas/models/granja.dart';
import 'package:ficha_medica_vacas/screens/granja_revision_screen.dart';

const losPinos = Granja(
  nombre: 'Los Pinos',
  dueno: 'Ana Pérez',
  superficie: 18,
  runsa: 'SC-02418',
  documento: 'Documento del terreno.pdf',
);

Future<void> abrir(WidgetTester tester, Widget pantalla) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: pantalla));
  await tester.pumpAndSettle();
}

Future<void> tocar(WidgetTester tester, String boton) async {
  await tester.ensureVisible(find.text(boton));
  await tester.pumpAndSettle();
  await tester.tap(find.text(boton));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Granja en revisión muestra los datos y vuelve al login', (tester) async {
    await abrir(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const GranjaRevisionScreen(granja: losPinos)),
          ),
          child: const Text('inicio'),
        ),
      ),
    );
    await tocar(tester, 'inicio');
    expect(find.text('Recibimos el registro de Los Pinos.'), findsOneWidget);
    expect(find.text('RUNSA: SC-02418'), findsOneWidget);
    await tocar(tester, 'Volver al login');
    expect(find.text('inicio'), findsOneWidget);
  });
}
