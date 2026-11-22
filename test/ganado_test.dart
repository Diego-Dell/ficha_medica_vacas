import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:ficha_medica_vacas/main_vista_previa.dart';
import 'package:ficha_medica_vacas/models/animal.dart';
import 'package:ficha_medica_vacas/screens/ganado/dar_de_baja_screen.dart';
import 'package:ficha_medica_vacas/screens/ganado/editar_ficha_screen.dart';
import 'package:ficha_medica_vacas/screens/ganado/ficha_animal_screen.dart';
import 'package:ficha_medica_vacas/screens/ganado/ganado_screen.dart';
import 'package:ficha_medica_vacas/widgets/selector_animal.dart';

import 'apoyo.dart';

const lucera = {
  'id': 'f1',
  'identificacion': '0842',
  'nombre': 'Lucera',
  'raza': 'Holstein',
  'etapa': 'vaca',
  'nacimiento': '2023-03-15',
  'nacimiento_estimado': true,
  'fecha_baja': null,
  'motivo_baja': null,
};
const rosa = {
  'id': 'f2',
  'identificacion': '0900',
  'nombre': null,
  'raza': null,
  'etapa': 'vaquilla',
  'nacimiento': null,
  'nacimiento_estimado': false,
  'fecha_baja': null,
  'motivo_baja': null,
};
final vendida = {
  ...lucera,
  'id': 'f3',
  'identificacion': '0100',
  'nombre': 'Mora',
  'fecha_baja': '2026-11-01',
  'motivo_baja': 'Venta del animal',
};

// 1. Abre la pantalla desde un inicio, como en la app.
Future<void> abrir(WidgetTester tester, Widget pantalla) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => pantalla)),
            child: const Text('inicio'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('inicio'));
  await tester.pumpAndSettle();
}

Future<void> tocar(WidgetTester tester, String boton) async {
  final objetivo = find.text(boton).last;
  await tester.ensureVisible(objetivo);
  await tester.pumpAndSettle();
  await tester.tap(objetivo);
  await tester.pumpAndSettle();
}

Future<void> elegir<T>(WidgetTester tester, String opcion, {int indice = 0}) async {
  await tester.tap(find.byType(DropdownButtonFormField<T>).at(indice));
  await tester.pumpAndSettle();
  await tester.tap(find.text(opcion).last);
  await tester.pumpAndSettle();
}

Map<String, dynamic> cuerpo(List<http.BaseRequest> pedidos, String metodo) =>
    jsonDecode((pedidos.singleWhere((p) => p.method == metodo) as http.Request).body) as Map<String, dynamic>;

void main() {
  setUp(() {
    entrarALosPinos();
    simularDatos({
      'fichas_bovinas': [lucera, rosa, vendida],
    });
  });

  testWidgets('Consulta lista también las bajas y filtra por texto y etapa', (tester) async {
    final pedidos = <http.BaseRequest>[];
    simularDatos({
      'fichas_bovinas': [lucera, rosa, vendida],
    }, pedidos: pedidos);
    await abrir(tester, const GanadoScreen());
    expect(find.text('Consulta y supervisión'), findsOneWidget);
    expect(find.text('Lucera · 0842  ›'), findsOneWidget);
    expect(find.text('Vaca · Holstein'), findsOneWidget);
    expect(find.text('Vaca · Holstein · De baja'), findsOneWidget);
    final consulta = pedidos.single.url.queryParameters;
    expect(consulta['granja_id'], 'eq.g1');
    expect(consulta.containsKey('fecha_baja'), isFalse);

    await tester.enterText(find.byType(TextField).first, 'luc');
    await tester.pump();
    expect(find.text('0900  ›'), findsNothing);
    expect(find.text('Lucera · 0842  ›'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '');
    await elegir<Etapa?>(tester, 'Vaquilla');
    expect(find.text('0900  ›'), findsOneWidget);
    expect(find.text('Lucera · 0842  ›'), findsNothing);
  });

  testWidgets('Consulta permite reintentar si no carga', (tester) async {
    simularDatos(const {}, sinRed: true);
    await abrir(tester, const GanadoScreen());
    await tester.pump(const Duration(minutes: 1));
    await tester.pumpAndSettle();
    simularDatos({
      'fichas_bovinas': const [lucera],
    });
    await tocar(tester, 'No se pudieron cargar los animales. Reintentar');
    expect(find.text('Lucera · 0842  ›'), findsOneWidget);
  });

  testWidgets('La ficha activa muestra su estado y datos', (tester) async {
    await abrir(tester, FichaAnimalScreen(animal: Animal.fromMap(lucera)));
    expect(find.text('Ficha e historial sanitario.'), findsOneWidget);
    expect(find.text('Activa · Vaca'), findsOneWidget);
    expect(find.text('Holstein · Nacimiento: 15/03/2023 (estimado)'), findsOneWidget);
    expect(find.text('Volver a la granja'), findsNothing);
  });

  testWidgets('La ficha dada de baja se conserva y vuelve a la granja', (tester) async {
    await abrir(tester, FichaAnimalScreen(animal: Animal.fromMap(vendida)));
    expect(find.text('Ficha conservada después de la baja.'), findsOneWidget);
    expect(find.text('De baja · 01/11/2026'), findsOneWidget);
    expect(find.text('Motivo: Venta del animal.'), findsOneWidget);
    expect(find.text('Esta ficha no admite nuevos eventos.'), findsOneWidget);
    await tocar(tester, 'Volver a la granja');
    expect(find.text('inicio'), findsOneWidget);
  });

  testWidgets('Ficha valida los obligatorios y crea con "Registro guardado"', (tester) async {
    final pedidos = <http.BaseRequest>[];
    simularDatos(const {}, pedidos: pedidos);
    await abrir(tester, const EditarFichaScreen());
    await tocar(tester, 'Guardar ficha');
    expect(find.text('Campo obligatorio'), findsNWidgets(2));
    expect(pedidos.where((p) => p.method == 'POST'), isEmpty);

    await tester.enterText(find.byType(TextFormField).at(0), ' 0950 ');
    await elegir<Etapa>(tester, 'Ternera');
    await tocar(tester, 'Guardar ficha');
    expect(cuerpo(pedidos, 'POST'), {
      'identificacion': '0950',
      'nombre': null,
      'raza': null,
      'etapa': 'ternera',
      'nacimiento': null,
      'nacimiento_estimado': false,
      'granja_id': 'g1',
    });
    expect(find.text('Registro guardado'), findsOneWidget);
    expect(find.text('Se conservan las relaciones y la autoría.'), findsOneWidget);
    await tocar(tester, 'Continuar');
    expect(find.text('inicio'), findsOneWidget);
  });

  testWidgets('Ficha carga una existente, la vacía y actualiza por id', (tester) async {
    final pedidos = <http.BaseRequest>[];
    simularDatos({
      'fichas_bovinas': const [lucera, rosa],
    }, pedidos: pedidos);
    await abrir(tester, const EditarFichaScreen());
    String campo(int i) => tester.widget<TextFormField>(find.byType(TextFormField).at(i)).controller!.text;

    await elegir<String?>(tester, 'Lucera · 0842');
    expect([campo(0), campo(1), campo(2)], ['0842', 'Lucera', 'Holstein']);
    expect(find.text('15/03/2023'), findsOneWidget);
    expect(find.text('Estimado'), findsOneWidget);

    await elegir<String?>(tester, 'Nueva ficha');
    expect([campo(0), campo(1), campo(2)], ['', '', '']);

    await elegir<String?>(tester, 'Lucera · 0842');
    await tester.enterText(find.byType(TextFormField).at(1), 'Lucerita');
    await tocar(tester, 'Guardar ficha');
    expect(pedidos.singleWhere((p) => p.method == 'PATCH').url.queryParameters['id'], 'eq.f1');
    expect(cuerpo(pedidos, 'PATCH')['nombre'], 'Lucerita');
    expect(cuerpo(pedidos, 'PATCH').containsKey('fecha_baja'), isFalse);
  });

  testWidgets('Ficha rechaza una identificación repetida en la granja', (tester) async {
    simularDatos(const {}, errorAlGuardar: '23505');
    await abrir(tester, const EditarFichaScreen());
    await tester.enterText(find.byType(TextFormField).at(0), '0842');
    await elegir<Etapa>(tester, 'Vaca');
    await tocar(tester, 'Guardar ficha');
    expect(find.text('Ya existe un animal con esa identificación en esta granja'), findsOneWidget);
    expect(find.text('Registro guardado'), findsNothing);
  });

  testWidgets('Baja pide animal y motivo, confirma y muestra la ficha conservada', (tester) async {
    final pedidos = <http.BaseRequest>[];
    simularDatos({
      'fichas_bovinas': const [lucera],
    }, pedidos: pedidos);
    await abrir(tester, const DarDeBajaScreen());
    expect(find.text('Baja del animal'), findsOneWidget);
    await tocar(tester, 'Confirmar baja');
    expect(find.text('Elegí un animal'), findsOneWidget);
    expect(find.text('Campo obligatorio'), findsOneWidget);

    await elegir<String>(tester, 'Lucera · 0842');
    await tester.enterText(find.byType(TextFormField), ' Venta del animal ');
    await tocar(tester, 'Confirmar baja');
    expect(find.text('¿Confirmar la baja?'), findsOneWidget);
    expect(find.text('Lucera · 0842 · Los Pinos'), findsOneWidget);
    await tocar(tester, 'Cancelar');
    expect(pedidos.where((p) => p.method == 'PATCH'), isEmpty);

    await tocar(tester, 'Confirmar baja');
    await tocar(tester, 'Sí, dar de baja');
    final datos = cuerpo(pedidos, 'PATCH');
    expect(datos['motivo_baja'], 'Venta del animal');
    expect(datos['fecha_baja'], matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
    expect(pedidos.last.url.queryParameters['id'], 'eq.f1', reason: 'vuelve a leer la ficha');
    expect(find.byType(FichaAnimalScreen), findsOneWidget);
    expect(find.text('Baja del animal'), findsNothing);
  });

  testWidgets('Baja avisa si la base la rechaza', (tester) async {
    simularDatos({
      'fichas_bovinas': const [lucera],
    }, errorAlGuardar: '42501');
    await abrir(tester, const DarDeBajaScreen());
    await elegir<String>(tester, 'Lucera · 0842');
    await tester.enterText(find.byType(TextFormField), 'Muerte');
    await tocar(tester, 'Confirmar baja');
    await tocar(tester, 'Sí, dar de baja');
    expect(find.text('Tu rol no permite este cambio'), findsOneWidget);
    expect(find.text('Baja del animal'), findsOneWidget);
  });

  testWidgets('SelectorAnimal ofrece solo activos y exige elegir uno', (tester) async {
    final form = GlobalKey<FormState>();
    Animal? elegido;
    await abrir(tester, Scaffold(body: Form(key: form, child: SelectorAnimal(alElegir: (a) => elegido = a))));
    expect(find.text('Animal de Los Pinos'), findsOneWidget);
    expect(form.currentState!.validate(), isFalse);
    await tester.pump();
    expect(find.text('Elegí un animal'), findsOneWidget);

    await elegir<String>(tester, '0900');
    expect(elegido?.id, 'f2');
    expect(form.currentState!.validate(), isTrue);
  });

  testWidgets('La vista previa abre Ficha sin romperse', (tester) async {
    await tester.pumpWidget(const VistaPreviaApp());
    await tester.tap(find.text('Trabajador'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ficha  ›'));
    await tester.pumpAndSettle();
    expect(find.text('Creá una ficha o seleccioná una para actualizarla.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
