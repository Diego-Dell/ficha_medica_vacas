import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ficha_medica_vacas/models/granja.dart';
import 'package:ficha_medica_vacas/screens/dueno_granja/granja_revision_screen.dart';

void main() {
  testWidgets('la pantalla de revisión muestra los datos del registro', (tester) async {
    const granja = Granja(
      id: 'granja-prueba',
      nombre: 'Santa Rosa',
      dueno: 'Ana Pérez',
      superficie: 12,
      runsa: 'SC-02419',
      documento: 'terreno.pdf',
      confirmada: false,
    );

    await tester.pumpWidget(
      const MaterialApp(home: GranjaRevisionScreen(granja: granja)),
    );

    expect(find.text('Granja en revisión'), findsOneWidget);
    expect(find.text('Recibimos el registro de Santa Rosa.'), findsOneWidget);
    expect(find.text('RUNSA: SC-02419'), findsOneWidget);
    expect(find.text('Volver al login'), findsOneWidget);
  });
}
