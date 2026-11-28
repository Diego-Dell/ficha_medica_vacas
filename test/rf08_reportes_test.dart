import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:ficha_medica_vacas/logic/clinica.dart';
import 'package:ficha_medica_vacas/logic/cuidados.dart';
import 'package:ficha_medica_vacas/logic/fichas.dart';
import 'package:ficha_medica_vacas/logic/reportes.dart';
import 'package:ficha_medica_vacas/logic/sesion.dart';
import 'package:ficha_medica_vacas/logic/tratamientos.dart';
import 'package:ficha_medica_vacas/models/animal.dart';
import 'package:ficha_medica_vacas/models/miembro.dart';
import 'package:ficha_medica_vacas/screens/administrador/operaciones_granja_screen.dart';
import 'package:ficha_medica_vacas/screens/dueno_granja/mi_granja_screen.dart';
import 'package:ficha_medica_vacas/screens/reportes_screen.dart';
import 'package:ficha_medica_vacas/screens/trabajador/cuidados_hoy_screen.dart';
import 'package:ficha_medica_vacas/screens/veterinario/seguimiento_veterinario_screen.dart';
import 'package:ficha_medica_vacas/widgets/panel_rol.dart';
import 'package:ficha_medica_vacas/widgets/vetlink.dart';

import 'apoyo.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final hoy = DateTime.now();
  final ayer = hoy.subtract(const Duration(days: 1));
  final haceTresDias = hoy.subtract(const Duration(days: 3));

  final fichasApi = [
    {
      'id': 'a1',
      'identificacion': '0842',
      'nombre': 'Lucera',
      'raza': 'Holstein',
      'etapa': 'Vaca',
      'nacimiento': '2022-05-10',
      'nacimientoEstimado': false,
    },
    {
      'id': 'a2',
      'identificacion': '0915',
      'nombre': 'Mora',
      'raza': 'Jersey',
      'etapa': 'Vaquilla',
      'fechaBaja': ayer.toIso8601String().substring(0, 10),
      'motivoBaja': 'Venta',
    },
  ];

  final atencionesApi = [
    {
      'id': 'at1',
      'fichaBovinaId': 'a1',
      'cuentaVeterinarioId': 'vet1',
      'fecha': ayer.toUtc().toIso8601String(),
      'tipo': 'Diagnostico',
      'detalle': 'Control general estable',
      'anulado': false,
    },
    {
      'id': 'at2',
      'fichaBovinaId': 'a1',
      'cuentaVeterinarioId': 'vet1',
      'fecha': haceTresDias.toUtc().toIso8601String(),
      'tipo': 'Control',
      'detalle': 'Registro corregido',
      'anulado': true,
    },
  ];

  final reproductivosApi = [
    {
      'id': 'rep1',
      'fichaBovinaId': 'a1',
      'cuentaVeterinarioId': 'vet1',
      'fecha': ayer.toUtc().toIso8601String(),
      'tipo': 'Valoracion',
      'aptitud': 'Apta',
      'prenez': 'Prenada',
      'anulado': false,
    },
  ];

  final tratamientosApi = [
    {
      'id': 'tr1',
      'fichaBovinaId': 'a1',
      'atencionClinicaId': 'at1',
      'cuentaVeterinarioId': 'vet1',
      'medicamento': 'Oxitetraciclina',
      'dosis': 5.0,
      'unidad': 'ml',
      'via': 'Intramuscular',
      'frecuencia': '24 h',
      'inicio': haceTresDias.toIso8601String().substring(0, 10),
      'duracion': '5 días',
      'retiro': '72 horas de retiro en leche',
      'anulado': false,
      'version': 1,
    },
  ];

  final prevencionesApi = [
    {
      'id': 'pr1',
      'fichaBovinaId': 'a1',
      'cuentaVeterinarioId': 'vet1',
      'tipo': 'Vacuna',
      'nombre': 'Aftosa anual',
      'fechaProgramada': haceTresDias.toIso8601String().substring(0, 10),
      'estado': 'Pendiente',
      'version': 1,
    },
    {
      'id': 'pr2',
      'fichaBovinaId': 'a1',
      'cuentaVeterinarioId': 'vet1',
      'tipo': 'Vacuna',
      'nombre': 'Brucelosis',
      'fechaProgramada': ayer.toIso8601String().substring(0, 10),
      'fechaRealizacion': ayer.toUtc().toIso8601String(),
      'estado': 'Realizada',
      'version': 1,
    },
  ];

  void configurarApiSimulada({
    List<Map<String, dynamic>>? fichas,
    bool fallarClinica = false,
    bool fallarTratamientos = false,
    bool fallarFichas = false,
  }) {
    final cliente = MockClient((pedido) async {
      final ruta = pedido.url.path;
      if (ruta.startsWith('/api/fichasbovinas')) {
        if (fallarFichas) return http.Response('{"error":"Sin conexión"}', 500);
        if (ruta.endsWith('/atenciones')) {
          if (fallarClinica) return http.Response('{"error":"Error clínica"}', 500);
          final id = pedido.url.pathSegments[2];
          return http.Response(
            jsonEncode(atencionesApi.where((a) => a['fichaBovinaId'] == id).toList()),
            200,
          );
        }
        return http.Response(jsonEncode(fichas ?? fichasApi), 200);
      }
      if (ruta == '/api/eventosreproductivos') {
        if (fallarClinica) return http.Response('{"error":"Error clínica"}', 500);
        return http.Response(jsonEncode(reproductivosApi), 200);
      }
      if (ruta == '/api/tratamientos') {
        if (fallarTratamientos) return http.Response('{"error":"Error tratamientos"}', 500);
        final fichaId = pedido.url.queryParameters['fichaBovinaId'];
        return http.Response(
          jsonEncode(
            fichaId == null
                ? tratamientosApi
                : tratamientosApi.where((t) => t['fichaBovinaId'] == fichaId).toList(),
          ),
          200,
        );
      }
      if (ruta == '/api/prevenciones') {
        if (fallarTratamientos) return http.Response('{"error":"Error prevenciones"}', 500);
        final fichaId = pedido.url.queryParameters['fichaBovinaId'];
        return http.Response(
          jsonEncode(
            fichaId == null
                ? prevencionesApi
                : prevencionesApi.where((p) => p['fichaBovinaId'] == fichaId).toList(),
          ),
          200,
        );
      }
      if (ruta == '/api/aplicaciones' || ruta == '/api/observacionescuidados') {
        return http.Response('[]', 200);
      }
      return http.Response('[]', 200);
    });

    Fichas.instance.usarApi('https://ejemplo.test', cliente);
    Clinica.instance.usarApi(
      'https://ejemplo.test',
      cliente,
      token: () => 'token-prueba',
      autor: () => 'vet1',
    );
    Tratamientos.instance.usarApi(
      'https://ejemplo.test',
      cliente,
      token: () => 'token-prueba',
    );
    Reportes.instance.usarCuidados(
      Cuidados(
        cliente: cliente,
        api: 'https://ejemplo.test',
        token: () => 'token-prueba',
      ),
    );
  }

  Future<void> abrir(WidgetTester tester, Widget pantalla) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(key: UniqueKey(), theme: temaVetLink(), home: pantalla),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tocar(WidgetTester tester, String texto) async {
    final objetivo = find.text(texto).last;
    await tester.ensureVisible(objetivo);
    await tester.pumpAndSettle();
    await tester.tap(objetivo);
    await tester.pumpAndSettle();
  }

  setUp(() {
    entrarALosPinos(rol: RolMiembro.dueno);
    simularDatos(tablasEquipo);
    configurarApiSimulada();
  });

  tearDown(() {
    Fichas.instance.usarApi('', http.Client());
    Clinica.instance.usarApi('', http.Client());
    Tratamientos.instance.usarApi('', http.Client());
    Reportes.instance.usarCuidados(null);
    Sesion.instance.auth = GoTrueClient(
      url: 'https://prueba.supabase.co/auth/v1',
      autoRefreshToken: false,
    );
  });

  test('Solo dueño, administrador y veterinario pueden generar reportes; trabajador es rechazado', () async {
    const vaca = Animal(id: 'a1', arete: '0842', nombre: 'Lucera', etapa: Etapa.vaca);

    for (final rol in [RolMiembro.dueno, RolMiembro.veterinario]) {
      entrarALosPinos(rol: rol);
      expect(Reportes.instance.puedeGenerar, isTrue);
      final reporte = await Reportes.instance.generarHistorialAnimal(vaca);
      expect(utf8.decode(reporte.pdf.take(5).toList()), '%PDF-');
      expect(reporte.pdf.length, greaterThan(500));
    }

    entrarALosPinos(rol: RolMiembro.trabajador);
    expect(Reportes.instance.puedeGenerar, isFalse);
    await expectLater(
      Reportes.instance.generarHistorialAnimal(vaca),
      throwsA(isA<FalloReporte>().having((e) => e.mensaje, 'mensaje', contains('dueño, administrador o veterinario'))),
    );
    await expectLater(
      Reportes.instance.generarResumenGranja(),
      throwsA(isA<FalloReporte>().having((e) => e.mensaje, 'mensaje', contains('dueño, administrador o veterinario'))),
    );
  });

  test('Genera ambos PDF válidos (%PDF-) con datos reales de la granja y periodo elegido', () async {
    const vaca = Animal(id: 'a1', arete: '0842', nombre: 'Lucera', etapa: Etapa.vaca);

    final historial = await Reportes.instance.generarHistorialAnimal(vaca);
    expect(historial.tipo, TipoReporte.historialAnimal);
    expect(historial.nombreArchivo, 'historial_0842_los_pinos.pdf');
    expect(utf8.decode(historial.pdf.take(5).toList()), '%PDF-');
    expect(historial.datosAnimal!.animal.arete, '0842');
    expect(historial.datosAnimal!.atenciones, hasLength(2));
    expect(historial.datosAnimal!.reproductivos, hasLength(1));
    expect(historial.datosAnimal!.tratamientos.single.medicamento, 'Oxitetraciclina');
    expect(historial.datosAnimal!.prevenciones, hasLength(2));

    final resumen = await Reportes.instance.generarResumenGranja(periodo: PeriodoReporte.mes);
    expect(resumen.tipo, TipoReporte.resumenGranja);
    expect(resumen.nombreArchivo, 'resumen_los_pinos.pdf');
    expect(utf8.decode(resumen.pdf.take(5).toList()), '%PDF-');
    expect(resumen.datosGranja!.granja.nombre, 'Los Pinos');
    expect(resumen.datosGranja!.animales, hasLength(2));
    expect(resumen.datosGranja!.activos, hasLength(1));
    expect(resumen.datosGranja!.bajas, hasLength(1));
    expect(resumen.datosGranja!.vacunasAplicadasPeriodo, 1);
    expect(resumen.datosGranja!.vencidos, 1);
  });

  test('Reportes falla con mensajes claros cuando faltan animales o falla la API', () async {
    configurarApiSimulada(fichas: const []);
    await expectLater(
      Reportes.instance.generarResumenGranja(),
      throwsA(isA<FalloReporte>().having((e) => e.mensaje, 'mensaje', contains('no tiene animales'))),
    );

    configurarApiSimulada(fallarClinica: true, fallarTratamientos: true);
    const vaca = Animal(id: 'a1', arete: '0842', nombre: 'Lucera', etapa: Etapa.vaca);
    await expectLater(
      Reportes.instance.generarHistorialAnimal(vaca),
      throwsA(isA<FalloReporte>()),
    );
    await expectLater(
      Reportes.instance.generarResumenGranja(),
      throwsA(isA<FalloReporte>().having((e) => e.mensaje, 'mensaje', contains('información sanitaria'))),
    );
  });

  testWidgets('Dueño navega desde barra inferior a Generar reportes, elige animal y descarga PDF', (tester) async {
    String? archivoDescargado;
    Uint8List? bytesDescargados;

    await abrir(tester, const MiGranjaScreen());
    for (final tab in ['Inicio', 'Ganado', 'Avisos', 'Reportes', 'Perfil']) {
      expect(
        find.descendant(of: find.byType(NavigationBar), matching: find.text(tab)),
        findsOneWidget,
      );
    }
    await tocar(tester, 'Reportes');
    expect(find.byType(ReportesScreen), findsOneWidget);
    expect(find.text('Generar reportes'), findsOneWidget);
    expect(find.text('Semana'), findsOneWidget);
    expect(find.text('Mes'), findsOneWidget);
    expect(find.text('Año'), findsOneWidget);
    expect(find.text('Animales activos'), findsOneWidget);
    expect(find.text('Atenciones'), findsOneWidget);
    expect(find.text('Vacunas aplicadas'), findsOneWidget);
    expect(find.text('Bajas del mes'), findsOneWidget);
    expect(find.text('Descargar reporte'), findsOneWidget);
    expect(find.text('Reportes en PDF'), findsOneWidget);
    expect(find.text('Resumen sanitario de la granja'), findsOneWidget);
    expect(find.text('Historial sanitario por animal'), findsOneWidget);

    await abrir(
      tester,
      ReportesScreen(
        alDescargar: (nombre, bytes) async {
          archivoDescargado = nombre;
          bytesDescargados = bytes;
          return '/descargas/$nombre';
        },
      ),
    );

    // Cambia entre Semana / Año / Mes sin errores.
    await tocar(tester, 'Semana');
    expect(find.text('Bajas de la semana'), findsOneWidget);
    await tocar(tester, 'Año');
    expect(find.text('Bajas del año'), findsOneWidget);
    await tocar(tester, 'Mes');

    // Abre selector de animal y elige Lucera · 0842.
    await tocar(tester, 'Historial sanitario por animal');
    expect(find.text('Seleccionar animal'), findsOneWidget);
    expect(find.text('De baja'), findsOneWidget);
    await tocar(tester, 'Lucera · 0842');

    expect(find.byType(VistaPreviaReporteScreen), findsOneWidget);
    expect(find.text('Historial sanitario'), findsOneWidget);
    expect(find.text('VetLink · Historial sanitario'), findsOneWidget);
    expect(find.text('Página 1 de 1'), findsOneWidget);
    expect(find.text('Visualizar PDF'), findsOneWidget);
    expect(find.text('Compartir'), findsOneWidget);
    expect(find.text('Descargar PDF'), findsOneWidget);
    expect(find.text('Oxitetraciclina'), findsOneWidget);
    expect(find.textContaining('Retiro: 72 horas'), findsOneWidget);
    expect(find.text('Anulado'), findsOneWidget);
    expect(find.text('Vencido'), findsOneWidget);

    await tocar(tester, 'Descargar PDF');
    expect(archivoDescargado, 'historial_0842_los_pinos.pdf');
    expect(bytesDescargados, isNotNull);
    expect(utf8.decode(bytesDescargados!.take(5).toList()), '%PDF-');
    expect(find.text('PDF guardado en Descargas'), findsOneWidget);
    expect(find.text('Abrir'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Veterinario genera y descarga resumen sanitario fiel a Figma con alertas en rojo', (tester) async {
    entrarALosPinos(rol: RolMiembro.veterinario);
    await abrir(tester, const SeguimientoVeterinarioScreen(granja: 'Los Pinos'));
    expect(find.byType(Acceso), findsNWidgets(4));
    expect(
      find.descendant(of: find.byType(NavigationBar), matching: find.text('Reportes')),
      findsOneWidget,
    );
    await tocar(tester, 'Reportes');
    expect(find.byType(ReportesScreen), findsOneWidget);

    String? archivoDescargado;
    Uint8List? bytesDescargados;
    await abrir(
      tester,
      ReportesScreen(
        alDescargar: (nombre, bytes) async {
          archivoDescargado = nombre;
          bytesDescargados = bytes;
          return '/descargas/$nombre';
        },
      ),
    );

    // Descarga directa desde Descargar reporte.
    await tocar(tester, 'Descargar reporte');
    expect(archivoDescargado, 'resumen_los_pinos.pdf');
    expect(utf8.decode(bytesDescargados!.take(5).toList()), '%PDF-');
    expect(find.text('PDF guardado en Descargas'), findsOneWidget);

    // Vista previa del resumen sanitario (Figma).
    await tocar(tester, 'Resumen sanitario de la granja');
    expect(find.byType(VistaPreviaReporteScreen), findsOneWidget);
    expect(find.text('Resumen sanitario'), findsOneWidget);
    expect(find.text('VetLink · Resumen sanitario'), findsOneWidget);
    expect(find.text('Animales activos'), findsOneWidget);
    expect(find.text('Atenciones clínicas'), findsOneWidget);
    expect(find.text('Tratamientos activos'), findsOneWidget);
    expect(find.text('Vacunas aplicadas'), findsOneWidget);
    expect(find.text('Controles vencidos'), findsOneWidget);
    expect(find.text('Bajas'), findsOneWidget);
    expect(find.text('Alerta sanitaria'), findsOneWidget);
    expect(find.text('Página 1 de 1'), findsOneWidget);
    expect(find.text('Compartir'), findsOneWidget);
    expect(find.text('Descargar PDF'), findsOneWidget);

    // Despliega detalle completo con alertas en rojo.
    await tocar(tester, 'Ver detalle completo');
    expect(find.textContaining('Mora · 0915'), findsOneWidget);
    expect(find.text('De baja'), findsOneWidget);
    expect(find.text('Vencido'), findsOneWidget);

    await tocar(tester, 'Descargar PDF');
    expect(archivoDescargado, 'resumen_los_pinos.pdf');
    expect(utf8.decode(bytesDescargados!.take(5).toList()), '%PDF-');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Administrador accede a Reportes desde Operaciones de la granja', (tester) async {
    String parte(Map<String, Object> datos) =>
        base64Url.encode(utf8.encode(jsonEncode(datos))).replaceAll('=', '');
    final vence = DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000;
    final auth = GoTrueClient(
      url: 'https://prueba.supabase.co/auth/v1',
      autoRefreshToken: false,
      httpClient: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'access_token': '${parte({'alg': 'HS256'})}.${parte({'sub': 'admin1', 'exp': vence})}.firma',
            'token_type': 'bearer',
            'expires_in': 3600,
            'refresh_token': 'r1',
            'user': {
              'id': 'admin1',
              'aud': 'authenticated',
              'email': 'admin@ejemplo.com',
              'created_at': '2026-11-01T00:00:00Z',
              'app_metadata': {},
              'user_metadata': {'nombre': 'Admin'},
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );
    addTearDown(auth.dispose);
    Sesion.instance.auth = auth;
    await auth.signInWithPassword(email: 'admin@ejemplo.com', password: 'clave');
    simularDatos({'es_administrador': true});

    await abrir(tester, const OperacionesGranjaScreen(granja: losPinos));
    expect(find.text('Los reportes se habilitarán al integrar RF-08 del equipo.'), findsNothing);
    expect(find.text('Reportes'), findsOneWidget);

    await tocar(tester, 'Reportes');
    expect(find.byType(ReportesScreen), findsOneWidget);
    expect(find.text('Generar reportes'), findsOneWidget);
    expect(find.text('Acceso restringido'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Trabajador no ve Reportes en barra inferior y la pantalla bloquea su acceso', (tester) async {
    entrarALosPinos(rol: RolMiembro.trabajador);
    await abrir(tester, const CuidadosHoyScreen(granja: 'Los Pinos'));
    expect(find.text('Reportes'), findsNothing);
    expect(find.byType(NavigationDestination), findsNWidgets(4));

    await abrir(tester, const ReportesScreen());
    expect(find.text('Acceso restringido'), findsOneWidget);
    expect(find.textContaining('Solo el dueño, administrador o veterinario'), findsOneWidget);
    expect(find.text('Descargar reporte'), findsNothing);
    final aviso = tester.widget<AvisoVetLink>(find.byType(AvisoVetLink));
    expect(aviso.peligro, isTrue);
  });

  testWidgets('Reportes muestra error rojo claro cuando fallan animales o falla la generación', (tester) async {
    configurarApiSimulada(fallarFichas: true);
    await abrir(tester, const ReportesScreen());

    expect(find.text('No se pudieron cargar los datos de la granja'), findsOneWidget);
    expect(find.text('Reintentar carga'), findsOneWidget);

    await tocar(tester, 'Resumen sanitario de la granja');
    expect(find.text('No se pudieron cargar las fichas del ganado. Revisá tu conexión e intentá nuevamente.'), findsOneWidget);
    expect(find.byType(VistaPreviaReporteScreen), findsNothing);
  });

  for (final ancho in [360.0, 390.0]) {
    testWidgets('Pantallas RF-08 y barra de 5 pestañas sin desbordamientos a $ancho px', (tester) async {
      tester.view.physicalSize = Size(ancho, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(theme: temaVetLink(), home: const MiGranjaScreen()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tocar(tester, 'Reportes');
      expect(tester.takeException(), isNull);

      await tocar(tester, 'Resumen sanitario de la granja');
      expect(find.byType(VistaPreviaReporteScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
