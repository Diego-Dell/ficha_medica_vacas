import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ficha_medica_vacas/logic/clinica.dart';
import 'package:ficha_medica_vacas/main_vista_previa.dart';
import 'package:ficha_medica_vacas/screens/trabajador/cuidados_hoy_screen.dart';
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
        unidad: 'mL',
        via: 'Prueba',
        frecuencia: 'Cada 12 horas',
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
    Tratamientos.instance.cliente = SupabaseClient(
      'https://prueba.supabase.co',
      'clave',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      postgrestOptions: const PostgrestClientOptions(retryEnabled: false),
      httpClient: MockClient((p) async {
        pedidos.add(p);
        return http.Response(
          codigo == 200
              ? 'null'
              : '{"code":"40001","message":"La indicación cambió"}',
          codigo,
          headers: {'content-type': 'application/json'},
          request: p,
        );
      }),
    );
  });
  tearDown(() {
    Tratamientos.instance.cliente = null;
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
      expect(
        pedidos.single.url.path,
        '/rest/v1/rpc/guardar_indicacion_tratamiento',
      );
      final cuerpo = jsonDecode(pedidos.single.body) as Map;
      expect(cuerpo['p_anterior'], isNull);
      expect(cuerpo['p_datos']['retiro'], 'Retiro de ejemplo');
      expect(cuerpo['p_datos']['inicio'], fechaApi(hoy));
      expect(cuerpo.containsKey('prescrito_por'), isFalse);
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
      'frecuencia': 'Diaria',
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
    expect(cuerpo['p_anterior'], 't1');
    expect(cuerpo['p_version'], 4);
    expect(cuerpo['p_motivo'], 'Ajuste');
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
    expect(find.text('Campo obligatorio'), findsNWidgets(5));
    expect(find.text('Ingresá una dosis positiva válida'), findsOneWidget);
    await tester.ensureVisible(find.byType(DropdownButtonFormField<String>));
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tocar(
      tester,
      '${fechaCorta(DateTime.parse(datos.atenciones.first['fecha'] as String).toLocal())} · Diagnóstico',
    );
    final campos = find.byType(TextFormField);
    for (final (i, texto) in [
      'Nuevo medicamento',
      '1,5',
      'mL',
      'Vía de prueba',
      'Cada 12 horas',
      '5 días',
      'Retiro de prueba',
    ].indexed) {
      await tester.ensureVisible(campos.at(i));
      await tester.enterText(campos.at(i), texto);
    }
    await tocar(tester, 'Guardar tratamiento');
    expect(find.text('Registro guardado'), findsOneWidget);
    expect(datos.tratamientos.last['dosis'], 1.5);
    expect(datos.tratamientos.last['retiro'], 'Retiro de prueba');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Prevención crea pendiente y completar control conserva el registro',
    (tester) async {
      final datos = DatosVistaPrevia();
      await datos.inicializar();
      final lucera = Animal.fromMap(datos.animales.first);
      await abrir(tester, PrevencionScreen(animal: lucera));
      await tester.enterText(find.byType(TextFormField), 'Vacuna de prueba');
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
      expect(find.byType(CuidadosHoyScreen), findsOneWidget);
      expect(find.text('Medicamento de ejemplo'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
