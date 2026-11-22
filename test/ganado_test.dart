import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:ficha_medica_vacas/screens/trabajador/cuidados_hoy_screen.dart';
import 'package:ficha_medica_vacas/models/animal.dart';
import 'package:ficha_medica_vacas/models/miembro.dart';
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
      key: UniqueKey(),
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

// 2. Toca una etapa en el filtro o en el selector del formulario.
Future<void> etapa(WidgetTester tester, String nombre) async {
  await tester.tap(find.text(nombre).last);
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

  testWidgets('Ganado lista también las bajas y filtra por texto y etapa', (tester) async {
    final pedidos = <http.BaseRequest>[];
    simularDatos({
      'fichas_bovinas': [lucera, rosa, vendida],
    }, pedidos: pedidos);
    await abrir(tester, const GanadoScreen());
    expect(find.text('Ganado'), findsOneWidget);
    expect(find.text('Lucera · 0842'), findsOneWidget);
    expect(find.text('Vaca · Holstein'), findsNWidgets(2));
    expect(find.text('De baja'), findsOneWidget);
    expect(find.text('2 animales · 1 de baja'), findsOneWidget);
    final consulta = pedidos.single.url.queryParameters;
    expect(consulta['granja_id'], 'eq.g1');
    expect(consulta.containsKey('fecha_baja'), isFalse);

    await tester.enterText(find.byType(TextField).first, 'luc');
    await tester.pump();
    expect(find.text('0900'), findsNothing);
    expect(find.text('Lucera · 0842'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '');
    await etapa(tester, 'Vaquilla');
    expect(find.text('0900'), findsOneWidget);
    expect(find.text('Lucera · 0842'), findsNothing);
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
    expect(find.text('Lucera · 0842'), findsOneWidget);
  });

  testWidgets('Nueva ficha solo aparece para dueño y trabajador', (tester) async {
    await abrir(tester, const GanadoScreen());
    expect(find.text('Nueva ficha'), findsOneWidget);
    entrarALosPinos(rol: RolMiembro.veterinario);
    await abrir(tester, const GanadoScreen());
    expect(find.text('Nueva ficha'), findsNothing);
  });

  testWidgets('La ficha activa muestra sus datos y las acciones según el rol', (tester) async {
    await abrir(tester, FichaAnimalScreen(animal: Animal.fromMap(lucera)));
    expect(find.text('Activa · Vaca'), findsOneWidget);
    expect(find.text('15/03/2023 · Estimado'), findsOneWidget);
    expect(find.text('Holstein'), findsOneWidget);
    expect(find.text('Editar ficha'), findsOneWidget);
    expect(find.text('Dar de baja'), findsOneWidget);
    expect(find.text('Volver a la granja'), findsNothing);
    await tocar(tester, 'Dar de baja');
    expect(find.byType(DarDeBajaScreen), findsOneWidget);

    entrarALosPinos(rol: RolMiembro.trabajador);
    await abrir(tester, FichaAnimalScreen(animal: Animal.fromMap(lucera)));
    expect(find.text('Editar ficha'), findsOneWidget);
    expect(find.text('Dar de baja'), findsNothing);

    entrarALosPinos(rol: RolMiembro.veterinario);
    await abrir(tester, FichaAnimalScreen(animal: Animal.fromMap(lucera)));
    expect(find.text('Editar ficha'), findsNothing);
    expect(find.text('Editar etapa'), findsOneWidget);
    expect(find.text('Dar de baja'), findsNothing);
  });

  testWidgets('La ficha dada de baja se conserva y vuelve a la granja', (tester) async {
    await abrir(tester, FichaAnimalScreen(animal: Animal.fromMap(vendida)));
    expect(find.text('Ficha conservada después de la baja.'), findsOneWidget);
    expect(find.text('De baja · 01/11/2026'), findsOneWidget);
    expect(find.text('Venta del animal'), findsOneWidget);
    expect(find.text('Esta ficha no admite nuevos eventos.'), findsOneWidget);
    expect(find.text('Editar ficha'), findsNothing);
    await tocar(tester, 'Volver a la granja');
    expect(find.text('inicio'), findsOneWidget);
  });

  testWidgets('Nueva ficha valida los obligatorios y crea con "Registro guardado"', (tester) async {
    final pedidos = <http.BaseRequest>[];
    simularDatos(const {}, pedidos: pedidos);
    await abrir(tester, const EditarFichaScreen());
    expect(find.text('Nueva ficha'), findsOneWidget);
    await tocar(tester, 'Guardar ficha');
    expect(find.text('Campo obligatorio'), findsNWidgets(2));
    expect(pedidos.where((p) => p.method == 'POST'), isEmpty);

    await tester.enterText(find.byType(TextFormField).at(0), ' 0950 ');
    await etapa(tester, 'Ternera');
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
    expect(find.text('La información de Los Pinos se guardó correctamente.'), findsOneWidget);
    await tocar(tester, 'Continuar');
    expect(find.text('inicio'), findsOneWidget);
  });

  testWidgets('Editar ficha carga los datos y actualiza por id', (tester) async {
    final pedidos = <http.BaseRequest>[];
    simularDatos({
      'fichas_bovinas': const [lucera],
    }, pedidos: pedidos);
    await abrir(tester, EditarFichaScreen(animal: Animal.fromMap(lucera)));
    String campo(int i) => tester.widget<TextFormField>(find.byType(TextFormField).at(i)).controller!.text;
    expect(find.text('Editar ficha'), findsOneWidget);
    expect([campo(0), campo(1), campo(2)], ['0842', 'Lucera', 'Holstein']);
    expect(find.text('15/03/2023'), findsOneWidget);
    expect(find.text('Estimado'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(1), 'Lucerita');
    await tocar(tester, 'Guardar ficha');
    expect(pedidos.singleWhere((p) => p.method == 'PATCH').url.queryParameters['id'], 'eq.f1');
    expect(cuerpo(pedidos, 'PATCH')['nombre'], 'Lucerita');
    expect(cuerpo(pedidos, 'PATCH').containsKey('fecha_baja'), isFalse);
  });

  testWidgets('Veterinario edita solo etapa y conserva los demás datos', (tester) async {
    entrarALosPinos(rol: RolMiembro.veterinario);
    final pedidos = <http.BaseRequest>[];
    simularDatos({'fichas_bovinas': const [lucera]}, pedidos: pedidos);
    await abrir(tester, EditarFichaScreen(animal: Animal.fromMap(lucera)));
    expect(find.text('Editar etapa'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
    await etapa(tester, 'Vaquilla');
    await tocar(tester, 'Guardar etapa');
    expect(cuerpo(pedidos, 'PATCH'), {'etapa': 'vaquilla'});
    expect(find.text('Registro guardado'), findsOneWidget);
  });

  testWidgets('Trabajador cambia nombre pero la etapa permanece bloqueada', (tester) async {
    entrarALosPinos(rol: RolMiembro.trabajador);
    final pedidos = <http.BaseRequest>[];
    simularDatos({'fichas_bovinas': const [lucera]}, pedidos: pedidos);
    await abrir(tester, EditarFichaScreen(animal: Animal.fromMap(lucera)));
    expect(find.text('Etapa (solo consulta)'), findsOneWidget);
    await etapa(tester, 'Vaquilla');
    await tester.enterText(find.byType(TextFormField).at(1), 'Lucerita');
    await tocar(tester, 'Guardar ficha');
    expect(cuerpo(pedidos, 'PATCH')['etapa'], 'vaca');
    expect(cuerpo(pedidos, 'PATCH')['nombre'], 'Lucerita');
    expect(find.text('Registro guardado'), findsOneWidget);
  });

  testWidgets('Nueva ficha rechaza una identificación repetida en la granja', (tester) async {
    simularDatos(const {}, errorAlGuardar: '23505');
    await abrir(tester, const EditarFichaScreen());
    await tester.enterText(find.byType(TextFormField).at(0), '0842');
    await etapa(tester, 'Vaca');
    await tocar(tester, 'Guardar ficha');
    expect(find.text('Ya existe un animal con esa identificación en esta granja'), findsOneWidget);
    expect(find.text('Registro guardado'), findsNothing);
  });

  testWidgets('Baja pide motivo, confirma y vuelve a la ficha', (tester) async {
    final pedidos = <http.BaseRequest>[];
    simularDatos({
      'fichas_bovinas': const [lucera],
    }, pedidos: pedidos);
    await abrir(tester, DarDeBajaScreen(animal: Animal.fromMap(lucera)));
    expect(find.text('Baja del animal'), findsOneWidget);
    expect(find.text('Lucera · 0842'), findsOneWidget);
    await tocar(tester, 'Confirmar baja');
    expect(find.text('Campo obligatorio'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), ' Venta del animal ');
    await tocar(tester, 'Confirmar baja');
    expect(find.text('¿Confirmar la baja?'), findsOneWidget);
    expect(find.textContaining('Lucera · 0842 · Los Pinos'), findsOneWidget);
    await tocar(tester, 'Cancelar');
    expect(pedidos.where((p) => p.method == 'PATCH'), isEmpty);

    await tocar(tester, 'Confirmar baja');
    await tocar(tester, 'Sí, dar de baja');
    final datos = cuerpo(pedidos, 'PATCH');
    expect(datos['motivo_baja'], 'Venta del animal');
    expect(datos['fecha_baja'], matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
    expect(find.text('Baja del animal'), findsNothing);
    expect(find.text('inicio'), findsOneWidget);
  });

  testWidgets('Baja avisa si la base la rechaza', (tester) async {
    simularDatos({
      'fichas_bovinas': const [lucera],
    }, errorAlGuardar: '42501');
    await abrir(tester, DarDeBajaScreen(animal: Animal.fromMap(lucera)));
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

  testWidgets('El trabajador abre Nueva ficha desde la pestaña Ganado', (tester) async {
    entrarALosPinos(rol: RolMiembro.trabajador);
    await tester.pumpWidget(const MaterialApp(home: CuidadosHoyScreen(granja: 'Los Pinos')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ganado'));
    await tester.pumpAndSettle();
    expect(find.text('Lucera · 0842'), findsOneWidget);
    await tester.tap(find.text('Nueva ficha'));
    await tester.pumpAndSettle();
    expect(find.text('Los campos con * son obligatorios.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
