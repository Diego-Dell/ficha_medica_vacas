import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:ficha_medica_vacas/models/animal.dart';
import 'package:ficha_medica_vacas/models/miembro.dart';
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

Future<void> abrir(WidgetTester tester, Widget pantalla) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: pantalla));
  await tester.pumpAndSettle();
}

Future<void> tocar(WidgetTester tester, String boton) async {
  final objetivo = find.text(boton);
  await tester.ensureVisible(objetivo);
  await tester.pumpAndSettle();
  await tester.tap(objetivo);
  await tester.pumpAndSettle();
}

/// 1. Devuelve el cuerpo JSON del único pedido que usó [metodo].
Map<String, dynamic> cuerpo(List<http.BaseRequest> pedidos, String metodo) =>
    jsonDecode((pedidos.singleWhere((p) => p.method == metodo) as http.Request).body) as Map<String, dynamic>;

void main() {
  setUp(() {
    entrarALosPinos();
    simularDatos({
      'fichas_bovinas': const [lucera, rosa],
    });
  });

  testWidgets('Ganado lista los animales activos y filtra por texto y etapa', (tester) async {
    final pedidos = <http.BaseRequest>[];
    simularDatos({
      'fichas_bovinas': const [lucera, rosa],
    }, pedidos: pedidos);
    await abrir(tester, const GanadoScreen());
    expect(find.text('2 animales'), findsOneWidget);
    expect(find.text('Lucera · 0842  ›'), findsOneWidget);
    expect(find.text('Vaca · Holstein · Activo'), findsOneWidget);
    expect(find.text('0900  ›'), findsOneWidget, reason: 'sin nombre muestra solo la identificación');
    final consulta = pedidos.single.url.queryParameters;
    expect(consulta['granja_id'], 'eq.g1');
    expect(consulta['fecha_baja'], 'is.null');

    await tester.enterText(find.byType(TextField).first, 'luc');
    await tester.pump();
    expect(find.text('1 animal'), findsOneWidget);
    expect(find.text('0900  ›'), findsNothing);

    await tester.enterText(find.byType(TextField).first, '');
    await tester.tap(find.byType(DropdownButtonFormField<Etapa?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vaquilla').last);
    await tester.pumpAndSettle();
    expect(find.text('1 animal'), findsOneWidget);
    expect(find.text('0900  ›'), findsOneWidget);
  });

  testWidgets('Ganado puede incluir los animales dados de baja', (tester) async {
    final pedidos = <http.BaseRequest>[];
    simularDatos({
      'fichas_bovinas': [lucera, vendida],
    }, pedidos: pedidos);
    await abrir(tester, const GanadoScreen());
    await tocar(tester, 'Incluir dados de baja');
    expect(pedidos.last.url.queryParameters.containsKey('fecha_baja'), isFalse);
    expect(find.text('Vaca · Holstein · Dado de baja'), findsOneWidget);
  });

  testWidgets('Ganado permite reintentar si no carga', (tester) async {
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

  testWidgets('El veterinario consulta fichas pero no las crea ni edita', (tester) async {
    entrarALosPinos(rol: RolMiembro.veterinario);
    await abrir(tester, const GanadoScreen());
    expect(find.text('Nueva ficha'), findsNothing);
    await tocar(tester, 'Lucera · 0842  ›');
    expect(find.text('Editar datos'), findsNothing);
    expect(find.text('Dar de baja'), findsNothing);
    expect(find.text('15/03/2023 (estimada)'), findsOneWidget);
  });

  testWidgets('El trabajador edita datos pero solo el dueño da de baja', (tester) async {
    entrarALosPinos(rol: RolMiembro.trabajador);
    await abrir(tester, const GanadoScreen());
    expect(find.text('Nueva ficha'), findsOneWidget);
    await tocar(tester, 'Lucera · 0842  ›');
    expect(find.text('Editar datos'), findsOneWidget);
    expect(find.text('Dar de baja'), findsNothing);
  });

  testWidgets('Nueva ficha valida los obligatorios y guarda en la granja actual', (tester) async {
    final pedidos = <http.BaseRequest>[];
    simularDatos(const {}, pedidos: pedidos);
    await abrir(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditarFichaScreen())),
            child: const Text('inicio'),
          ),
        ),
      ),
    );
    await tocar(tester, 'inicio');
    await tocar(tester, 'Guardar ficha');
    expect(find.text('Campo obligatorio'), findsNWidgets(2));
    expect(pedidos, isEmpty);

    await tester.enterText(find.byType(TextFormField).at(0), ' 0950 ');
    await tester.enterText(find.byType(TextFormField).at(1), ' ');
    await tester.tap(find.byType(DropdownButtonFormField<Etapa>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ternera').last);
    await tester.pumpAndSettle();
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
    expect(find.text('Se creó la ficha de 0950'), findsOneWidget);
    expect(find.text('inicio'), findsOneWidget);
  });

  testWidgets('Nueva ficha rechaza una identificación repetida en la granja', (tester) async {
    simularDatos(const {}, errorAlGuardar: '23505');
    await abrir(tester, const EditarFichaScreen());
    await tester.enterText(find.byType(TextFormField).at(0), '0842');
    await tester.tap(find.byType(DropdownButtonFormField<Etapa>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vaca').last);
    await tester.pumpAndSettle();
    await tocar(tester, 'Guardar ficha');
    expect(find.text('Ya existe un animal con esa identificación en esta granja'), findsOneWidget);
    expect(find.text('Nueva ficha'), findsOneWidget);
  });

  testWidgets('Editar conserva el id del animal y actualiza la ficha al volver', (tester) async {
    final pedidos = <http.BaseRequest>[];
    simularDatos({
      'fichas_bovinas': {...lucera, 'identificacion': '0843'},
    }, pedidos: pedidos);
    await abrir(tester, FichaAnimalScreen(animal: Animal.fromMap(lucera)));
    await tocar(tester, 'Editar datos');
    expect(find.text('Editar ficha'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(0), '0843');
    await tocar(tester, 'Guardar ficha');
    final cambio = pedidos.singleWhere((p) => p.method == 'PATCH');
    expect(cambio.url.queryParameters['id'], 'eq.f1');
    expect(cuerpo(pedidos, 'PATCH')['identificacion'], '0843');
    expect(cuerpo(pedidos, 'PATCH').containsKey('fecha_baja'), isFalse);
    expect(find.text('Lucera · 0843'), findsOneWidget);
  });

  testWidgets('Dar de baja pide el motivo, guarda y deja la ficha consultable', (tester) async {
    final pedidos = <http.BaseRequest>[];
    simularDatos({
      'fichas_bovinas': {...lucera, 'fecha_baja': '2026-11-18', 'motivo_baja': 'Venta del animal'},
    }, pedidos: pedidos);
    await abrir(tester, FichaAnimalScreen(animal: Animal.fromMap(lucera)));
    await tocar(tester, 'Dar de baja');
    await tocar(tester, 'Confirmar baja');
    expect(find.text('Campo obligatorio'), findsOneWidget);
    expect(pedidos.where((p) => p.method == 'PATCH'), isEmpty);

    await tester.enterText(find.byType(TextFormField), ' Venta del animal ');
    await tocar(tester, 'Confirmar baja');
    final datos = cuerpo(pedidos, 'PATCH');
    expect(datos['motivo_baja'], 'Venta del animal');
    expect(datos['fecha_baja'], matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
    expect(find.text('Dado de baja el 18/11/2026'), findsOneWidget);
    expect(find.text('Editar datos'), findsNothing);
    expect(find.text('Dar de baja'), findsNothing);
  });

  testWidgets('Dar de baja avisa si falla', (tester) async {
    simularDatos(const {}, errorAlGuardar: '42501');
    await abrir(tester, FichaAnimalScreen(animal: Animal.fromMap(lucera)));
    await tocar(tester, 'Dar de baja');
    await tester.enterText(find.byType(TextFormField), 'Muerte');
    await tocar(tester, 'Confirmar baja');
    expect(find.text('Tu rol no permite este cambio'), findsOneWidget);
    expect(find.text('Confirmar baja'), findsOneWidget);
  });

  testWidgets('Una ficha dada de baja muestra el motivo y no admite cambios', (tester) async {
    await abrir(tester, FichaAnimalScreen(animal: Animal.fromMap(vendida)));
    expect(find.text('Dado de baja el 01/11/2026'), findsOneWidget);
    expect(find.textContaining('Motivo: Venta del animal.'), findsOneWidget);
    expect(find.text('Editar datos'), findsNothing);
    expect(find.text('Dar de baja'), findsNothing);
  });

  testWidgets('SelectorAnimal ofrece solo animales activos y exige elegir uno', (tester) async {
    final form = GlobalKey<FormState>();
    Animal? elegido;
    await abrir(
      tester,
      Scaffold(
        body: Form(key: form, child: SelectorAnimal(alElegir: (a) => elegido = a)),
      ),
    );
    expect(find.text('Animal de Los Pinos *'), findsOneWidget);
    expect(form.currentState!.validate(), isFalse);
    await tester.pump();
    expect(find.text('Elegí un animal'), findsOneWidget);

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('0900').last);
    await tester.pumpAndSettle();
    expect(elegido?.id, 'f2');
    expect(form.currentState!.validate(), isTrue);
  });
}
