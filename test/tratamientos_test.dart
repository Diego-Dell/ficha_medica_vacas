import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ficha_medica_vacas/logic/clinica.dart';
import 'package:ficha_medica_vacas/main_vista_previa.dart';
import 'package:ficha_medica_vacas/screens/tratamientos_prevencion_screen.dart';
import 'package:ficha_medica_vacas/logic/tratamientos.dart';
import 'package:ficha_medica_vacas/models/animal.dart';
import 'package:ficha_medica_vacas/models/miembro.dart';
import 'package:ficha_medica_vacas/models/registro_clinico.dart';
import 'package:ficha_medica_vacas/models/tratamiento.dart';
import 'package:ficha_medica_vacas/preview/datos_vista_previa.dart';
import 'package:ficha_medica_vacas/screens/veterinario/tratamiento_screen.dart';
import 'package:ficha_medica_vacas/screens/veterinario/prevencion_screen.dart';
import 'package:ficha_medica_vacas/widgets/historial_tratamientos.dart';
import 'package:ficha_medica_vacas/widgets/vetlink.dart';

import 'apoyo.dart';

void main() {
  const animal = Animal(id: 'f1', arete: '0842', etapa: Etapa.vaca);
  final hoy = DateUtils.dateOnly(DateTime.now());
  final atencion = RegistroClinico.desdeApi({
    'id': 'a1',
    'fichaBovinaId': 'f1',
    'cuentaVeterinarioId': 'vet1',
    'fecha': hoy.subtract(const Duration(days: 1)).toUtc().toIso8601String(),
    'tipo': 'Diagnostico',
  }, reproductivo: false);
  IndicacionTratamiento indicacion({double dosis = 2.5}) =>
      IndicacionTratamiento(
        medicamento: 'Indicación de prueba',
        dosis: dosis,
        unidad: 'ml',
        via: 'Prueba',
        frecuencia: '12 h',
        inicio: hoy,
        duracion: '3 días',
        retiro: 'Retiro de ejemplo',
      );
  final pedidos = <http.Request>[];
  var codigo = 200;
  setUp(() {
    pedidos.clear();
    codigo = 200;
    entrarALosPinos(rol: RolMiembro.veterinario);
    Tratamientos.instance.usarApi(
      'http://localhost:5080',
      MockClient((p) async {
        pedidos.add(p);
        return http.Response(
          codigo == 200 ? 'null' : '{"error":"La indicación cambió"}',
          codigo,
          headers: {'content-type': 'application/json'},
          request: p,
        );
      }),
      token: () => 'token-de-prueba',
    );
  });
  tearDown(() {
    Tratamientos.instance.usarApi('', http.Client());
    Clinica.instance.usarApi('', http.Client());
  });

  test(
    'Crea con retiro y fecha sin hora en una sola llamada y sin autor editable',
    () async {
      expect(
        await Tratamientos.instance.guardar(
          animal: animal,
          atencion: atencion,
          indicacion: indicacion(),
        ),
        isNull,
      );
      expect(pedidos.single.url.path, '/api/tratamientos');
      final cuerpo = jsonDecode(pedidos.single.body) as Map;
      expect(cuerpo['fichaBovinaId'], 'f1');
      expect(cuerpo['retiro'], 'Retiro de ejemplo');
      expect(cuerpo['inicio'], fechaApi(hoy));
      expect(cuerpo.containsKey('cuentaVeterinarioId'), isFalse);
    },
  );

  test('Rechaza trabajador, baja, atención de otro animal y dosis inválida sin enviar', () async {
    entrarALosPinos(rol: RolMiembro.trabajador);
    expect(
      await Tratamientos.instance.guardar(
        animal: animal,
        atencion: atencion,
        indicacion: indicacion(),
      ),
      contains('veterinario'),
    );
    entrarALosPinos(rol: RolMiembro.veterinario);
    expect(
      await Tratamientos.instance.guardar(
        animal: Animal(
          id: 'f1',
          arete: '0842',
          etapa: Etapa.vaca,
          fechaBaja: hoy,
        ),
        atencion: atencion,
        indicacion: indicacion(),
      ),
      contains('baja'),
    );
    expect(
      await Tratamientos.instance.guardar(
        animal: const Animal(id: 'f2', arete: 'Otro', etapa: Etapa.vaca),
        atencion: atencion,
        indicacion: indicacion(),
      ),
      contains('mismo animal'),
    );
    for (final dosis in [0.0, -1.0, double.nan, double.infinity]) {
      expect(
        await Tratamientos.instance.guardar(
          animal: animal,
          atencion: atencion,
          indicacion: indicacion(dosis: dosis),
        ),
        isNotNull,
      );
    }
    expect(pedidos, isEmpty);
  });

  test('El reemplazo envía referencia, versión y cierre juntos; un conflicto se informa', () async {
    final anterior = Tratamiento.fromMap({
      'id': 't1',
      'ficha_id': 'f1',
      'atencion_id': 'a1',
      'prescrito_por': 'vet1',
      'medicamento': 'Anterior',
      'dosis': 3,
      'unidad': 'mL',
      'via': 'Prueba',
      'frecuencia': '24 h',
      'inicio': fechaApi(hoy),
      'duracion': '2 días',
      'version': 4,
    });
    expect(
      await Tratamientos.instance.guardar(
        animal: animal,
        atencion: atencion,
        indicacion: indicacion(),
        anterior: anterior,
        fechaFin: hoy,
        motivoFin: '',
      ),
      contains('motivo'),
    );
    expect(pedidos, isEmpty);
    codigo = 409;
    expect(
      await Tratamientos.instance.guardar(
        animal: animal,
        atencion: atencion,
        indicacion: indicacion(),
        anterior: anterior,
        fechaFin: hoy,
        motivoFin: 'Ajuste',
      ),
      contains('cambió'),
    );
    final cuerpo = jsonDecode(pedidos.single.body) as Map;
    expect(pedidos.single.url.path, '/api/tratamientos/t1/reemplazar');
    expect(cuerpo['version'], 4);
    expect(cuerpo['motivoFinAnterior'], 'Ajuste');
    expect(anterior.dosis, 3);
  });

  Future<void> abrir(WidgetTester tester, Widget pantalla) async {
    tester.view.physicalSize = const Size(360, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(key: UniqueKey(), theme: temaVetLink(), home: pantalla),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tocar(WidgetTester tester, String texto) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(texto).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text(texto).last);
    await tester.pumpAndSettle();
  }

  testWidgets('Tratamiento valida dosis y guarda desde la atención del animal', (
    tester,
  ) async {
    final datos = DatosVistaPrevia();
    await datos.inicializar();
    final lucera = Animal.fromMap(datos.animales.first);
    await abrir(tester, TratamientoScreen(animal: lucera));
    await tocar(tester, 'Guardar tratamiento');
    expect(find.text('Campo obligatorio'), findsNWidgets(2));
    expect(find.text('Ingresá una dosis positiva válida'), findsOneWidget);
    expect(find.text('Elegí la unidad'), findsOneWidget);
    expect(find.text('Entre 1 y 720'), findsOneWidget);
    expect(find.text('Entre 1 y 365'), findsOneWidget);
    await tester.ensureVisible(find.byType(DropdownButtonFormField<String>).first);
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tocar(
      tester,
      '${fechaCorta(DateTime.parse(datos.atenciones.first['fecha'] as String).toLocal())} · Diagnóstico',
    );
    final campos = find.byType(TextFormField);
    for (final (i, texto) in [
      'Nuevo medicamento',
      '1,5',
      'Vía de prueba',
      '12',
      '5',
      'Retiro de prueba',
    ].indexed) {
      await tester.ensureVisible(campos.at(i));
      await tester.enterText(campos.at(i), texto);
    }
    // Unidad elegida de la lista y total de dosis calculado (5 días cada 12 h).
    await tester.ensureVisible(find.byType(DropdownButtonFormField<String>).last);
    await tester.tap(find.byType(DropdownButtonFormField<String>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('ml').last);
    await tester.pumpAndSettle();
    expect(find.text('Total de dosis: 10'), findsOneWidget);
    await tocar(tester, 'Guardar tratamiento');
    expect(find.text('Registro guardado'), findsOneWidget);
    expect(datos.tratamientos.last['dosis'], 1.5);
    expect(datos.tratamientos.last['retiro'], 'Retiro de prueba');
    expect(datos.tratamientos.last['unidad'], 'ml');
    expect(datos.tratamientos.last['frecuencia'], '12 h');
    expect(datos.tratamientos.last['duracion'], '5 días');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Prevención crea pendiente y completar control conserva el registro',
    (tester) async {
      final datos = DatosVistaPrevia();
      await datos.inicializar();
      final lucera = Animal.fromMap(datos.animales.first);
      await abrir(tester, PrevencionScreen(animal: lucera));
      await tester.enterText(find.byType(TextFormField).at(0), 'Vacuna de prueba');
      await tester.enterText(find.byType(TextFormField).at(1), '2');
      await tester.tap(find.byType(DropdownButtonFormField<String>).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('ml').last);
      await tester.pumpAndSettle();
      await tocar(tester, 'Programar prevención');
      expect(find.text('Registro guardado'), findsOneWidget);
      expect(datos.prevenciones.last['estado'], 'pendiente');
      await abrir(
        tester,
        SingleChildScrollView(child: HistorialTratamientos(animal: lucera)),
      );
      await tocar(tester, 'Completar control');
      await tocar(tester, 'Completar control');
      expect(find.text('Registro guardado'), findsOneWidget);
      expect(datos.prevenciones.first['estado'], 'realizada');
      expect(datos.prevenciones.first['nombre'], 'Control de seguimiento');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'El trabajador consulta el historial sin acciones de prescripción',
    (tester) async {
      final datos = DatosVistaPrevia();
      await datos.inicializar();
      datos.seleccionar(RolMiembro.trabajador);
      await abrir(
        tester,
        Scaffold(
          body: SingleChildScrollView(
            child: HistorialTratamientos(
              animal: Animal.fromMap(datos.animales.first),
            ),
          ),
        ),
      );
      expect(find.text('Medicamento de ejemplo'), findsOneWidget);
      expect(find.text('Modificar'), findsNothing);
      expect(find.text('Finalizar'), findsNothing);
      expect(find.text('Completar control'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'La vista previa cambia de veterinario a trabajador y muestra la indicación',
    (tester) async {
      final datos = DatosVistaPrevia();
      await datos.inicializar();
      await tester.pumpWidget(VistaPreviaApp(datos: datos));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cambiar a Trabajador'));
      await tester.pumpAndSettle();
      expect(find.byType(TratamientosPrevencionScreen), findsOneWidget);
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tocar(tester, 'Lucera · 0842');
      expect(find.text('Medicamento de ejemplo'), findsOneWidget);
      expect(find.text('Indicar tratamiento'), findsNothing);
      expect(find.text('Programar prevención'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Modificar y finalizar conserva las dos indicaciones y sus dosis',
    (tester) async {
      final datos = DatosVistaPrevia();
      await datos.inicializar();
      final lucera = Animal.fromMap(datos.animales.first);
      final anterior = Tratamiento.fromMap(datos.tratamientos.first);
      await abrir(
        tester,
        TratamientoScreen(animal: lucera, anterior: anterior),
      );
      final campos = find.byType(TextFormField);
      await tester.enterText(campos.at(0), 'Ajuste de indicación');
      await tester.ensureVisible(campos.at(2));
      await tester.enterText(campos.at(2), '1,5');
      await tocar(tester, 'Guardar tratamiento');
      expect(find.text('Registro guardado'), findsOneWidget);
      expect(datos.tratamientos.length, 2);
      expect(datos.tratamientos.first['dosis'], 2.5);
      expect(datos.tratamientos.first['motivo_fin'], 'Ajuste de indicación');
      expect(datos.tratamientos.last['dosis'], 1.5);
      expect(datos.tratamientos.last['anterior_id'], anterior.id);
      final nueva = Tratamiento.fromMap(datos.tratamientos.last);
      await abrir(
        tester,
        TratamientoScreen(animal: lucera, anterior: nueva, finalizar: true),
      );
      await tester.enterText(
        find.byType(TextFormField),
        'Tratamiento completado',
      );
      await tocar(tester, 'Finalizar tratamiento');
      expect(find.text('Registro guardado'), findsOneWidget);
      expect(datos.tratamientos.last['motivo_fin'], 'Tratamiento completado');
      expect(datos.tratamientos.last['dosis'], 1.5);
      expect(tester.takeException(), isNull);
    },
  );

  for (final ancho in [360.0, 390.0]) {
    testWidgets(
      'Inicio del integrante 3 sin otros módulos ni desbordamientos a $ancho',
      (tester) async {
        tester.view.physicalSize = Size(ancho, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final datos = DatosVistaPrevia();
        await datos.inicializar();
        await tester.pumpWidget(VistaPreviaApp(datos: datos));
        await tester.pumpAndSettle();
        expect(find.text('Tratamientos y prevención'), findsOneWidget);
        for (final otroModulo in [
          'Clínica',
          'Reproducción',
          'Observación',
          'Aplicación',
          'Miembros',
          'Administración',
        ]) {
          expect(find.text(otroModulo), findsNothing);
        }
        await tester.tap(find.byType(DropdownButtonFormField<String>));
        await tester.pumpAndSettle();
        await tocar(tester, 'Lucera · 0842');
        expect(find.text('Indicar tratamiento'), findsOneWidget);
        expect(find.text('Programar prevención'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
