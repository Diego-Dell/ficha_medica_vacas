import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ficha_medica_vacas/logic/clinica.dart';
import 'package:ficha_medica_vacas/models/miembro.dart';
import 'package:ficha_medica_vacas/screens/veterinario/registro_clinico_screen.dart';
import 'package:ficha_medica_vacas/widgets/vetlink.dart';
import 'apoyo.dart';

void main() {
  final pedidos = <http.Request>[];
  setUp(() {
    entrarALosPinos(rol: RolMiembro.veterinario);
    simularDatos({'fichas_bovinas': [
      {'id': 'f1', 'identificacion': '0842', 'nombre': 'Lucera', 'raza': 'Holstein', 'etapa': 'vaca'},
    ]});
    pedidos.clear();
    Clinica.instance.usarApi('https://ejemplo.test', MockClient((p) async {
      pedidos.add(p);
      return http.Response('', 201);
    }), token: () => 'token', autor: () => 'vet1');
  });
  tearDown(() => Clinica.instance.usarApi('', http.Client()));

  Future<void> abrir(WidgetTester tester, {bool reproductivo = false}) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: temaVetLink(), home: RegistroClinicoScreen(reproductivo: reproductivo)));
    await tester.pumpAndSettle();
  }
  Future<void> tocar(WidgetTester tester, String texto) async {
    await tester.ensureVisible(find.text(texto).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text(texto).last);
    await tester.pumpAndSettle();
  }
  Future<void> animal(WidgetTester tester) async {
    final selector = find.byType(DropdownButtonFormField<String>).first;
    await tester.ensureVisible(selector);
    await tester.pumpAndSettle();
    await tester.tap(selector);
    await tester.pumpAndSettle();
    await tocar(tester, 'Lucera · 0842');
  }

  testWidgets('Clínica valida y guarda los tres campos sin perder información', (tester) async {
    await abrir(tester);
    await tocar(tester, 'Guardar registro');
    expect(pedidos, isEmpty);
    expect(find.text('Campo obligatorio'), findsNWidgets(2));
    await animal(tester);
    final campos = find.byType(TextFormField);
    await tester.enterText(campos.at(0), 'Signos de ejemplo');
    await tester.enterText(campos.at(1), 'Valoración de ejemplo');
    await tester.enterText(campos.at(2), 'Seguimiento indicado');
    await tocar(tester, 'Guardar registro');
    final cuerpo = jsonDecode(pedidos.single.body) as Map;
    expect(cuerpo['fichaBovinaId'], 'f1');
    expect(cuerpo['detalle'], 'Signos observados: Signos de ejemplo\nDiagnóstico: Valoración de ejemplo\nIndicaciones: Seguimiento indicado');
    expect(find.text('Registro guardado'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Reproducción guarda valoración sin inventar aptitud ni fechas', (tester) async {
    await abrir(tester, reproductivo: true);
    await animal(tester);
    await tester.enterText(find.byType(TextFormField), 'Evaluación inicial');
    await tocar(tester, 'Guardar valoración');
    final cuerpo = jsonDecode(pedidos.single.body) as Map;
    expect(cuerpo['tipo'], 'Valoracion');
    expect(cuerpo['aptitud'], isNull);
    expect(cuerpo['prenez'], 'NoEvaluada');
    expect(cuerpo['proximoControl'], isNull);
    expect(cuerpo['partoProbable'], isNull);
    expect(find.text('Registro guardado'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('No guarda parto con preñez todavía confirmada', (tester) async {
    await abrir(tester, reproductivo: true);
    await animal(tester);
    await tocar(tester, 'Confirmada');
    await tocar(tester, 'Sin evento');
    await tocar(tester, 'Parto');
    await tester.enterText(find.byType(TextFormField), 'Parto registrado');
    await tocar(tester, 'Guardar valoración');
    expect(pedidos, isEmpty);
    expect(find.textContaining('indicá No gestante'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
