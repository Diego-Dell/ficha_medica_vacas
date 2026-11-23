import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:ficha_medica_vacas/logic/granjas.dart';
import 'package:ficha_medica_vacas/models/miembro.dart';
import 'package:ficha_medica_vacas/screens/dueno_granja/datos_granja_screen.dart';
import 'package:ficha_medica_vacas/screens/dueno_granja/mi_granja_screen.dart';

import 'apoyo.dart';

void main() {
  setUp(entrarALosPinos);

  // 1. Abre Datos de la granja desde el inicio del dueño.
  Future<void> abrirDatos(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: MiGranjaScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Datos de la granja'));
    await tester.pumpAndSettle();
  }

  testWidgets('El dueño actualiza el RUNSA y el inicio muestra el nuevo', (tester) async {
    final pedidos = <http.BaseRequest>[];
    simularDatos({'granjas': [filaLosPinos]}, pedidos: pedidos);
    await abrirDatos(tester);
    expect(find.byType(DatosGranjaScreen), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), '');
    await tester.tap(find.text('Guardar cambios'));
    await tester.pumpAndSettle();
    expect(find.text('Campo obligatorio'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), ' sc-09999 ');
    await tester.tap(find.text('Guardar cambios'));
    await tester.pumpAndSettle();
    final patch = pedidos.singleWhere((p) => p.method == 'PATCH') as http.Request;
    expect(jsonDecode(patch.body), {'runsa': 'SC-09999'});
    expect(patch.url.queryParameters['id'], 'eq.g1');
    expect(Granjas.instance.actual.runsa, 'SC-09999');
    expect(find.text('RUNSA SC-09999'), findsOneWidget);
  });

  testWidgets('Si la base no cambia ninguna fila avisa que el rol no lo permite', (tester) async {
    simularDatos(const {});
    await abrirDatos(tester);
    await tester.enterText(find.byType(TextFormField), 'SC-1');
    await tester.tap(find.text('Guardar cambios'));
    await tester.pumpAndSettle();
    expect(find.text('Tu rol no permite este cambio'), findsOneWidget);
    expect(find.byType(DatosGranjaScreen), findsOneWidget);
  });

  testWidgets('Solo el dueño ve Datos de la granja', (tester) async {
    entrarALosPinos(rol: RolMiembro.trabajador);
    await tester.pumpWidget(const MaterialApp(home: MiGranjaScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Datos de la granja'), findsNothing);
  });
}
