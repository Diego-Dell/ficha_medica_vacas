import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:ficha_medica_vacas/logic/sesion.dart';
import 'package:ficha_medica_vacas/models/miembro.dart';
import 'package:ficha_medica_vacas/screens/administrador/administracion_screen.dart';
import 'package:ficha_medica_vacas/screens/dueno_granja/granja_revision_screen.dart';
import 'package:ficha_medica_vacas/screens/dueno_granja/invitar_screen.dart';
import 'package:ficha_medica_vacas/screens/dueno_granja/mi_granja_screen.dart';
import 'package:ficha_medica_vacas/screens/dueno_granja/miembros_screen.dart';
import 'package:ficha_medica_vacas/screens/dueno_granja/registrar_granja_screen.dart';
import 'package:ficha_medica_vacas/screens/dueno_granja/registrar_otra_granja_screen.dart';

import 'apoyo.dart';

Future<void> abrir(WidgetTester tester, Widget pantalla) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: pantalla));
  await tester.pumpAndSettle();
}

/// 1. Toca un botón; con [atajo], toca el enlace "‹ Volver" del encabezado.
Future<void> tocar(WidgetTester tester, String boton, {bool atajo = false}) async {
  final objetivo = atajo ? find.text('‹ $boton').first : find.text(boton);
  await tester.ensureVisible(objetivo);
  await tester.pumpAndSettle();
  await tester.tap(objetivo);
  await tester.pumpAndSettle();

  // 2. Da tiempo real al cliente de funciones, que prepara el envío en otro hilo.
  if (boton == 'Enviar invitación' || boton == 'Reenviar invitación') {
    for (var intento = 0; intento < 50; intento++) {
      if (find.text('Enviando...').evaluate().isEmpty && find.text('Reenviando...').evaluate().isEmpty) break;
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }
}

GoTrueClient cliente(MockClientHandler respuesta) => GoTrueClient(
      url: 'https://prueba.supabase.co/auth/v1',
      httpClient: MockClient(respuesta),
      autoRefreshToken: false,
      flowType: AuthFlowType.implicit,
    );

void main() {
  setUp(() {
    entrarALosPinos();
    simularDatos(tablasEquipo);
  });

  testWidgets('Registrar mi granja valida, envía los datos y pasa a revisión', (tester) async {
    late Map<String, dynamic> enviado;
    Sesion.instance.auth = cliente((pedido) async {
      enviado = jsonDecode(pedido.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode({
          'id': '1',
          'aud': 'authenticated',
          'email': 'ana@ejemplo.com',
          'created_at': '2026-11-02T00:00:00Z',
          'app_metadata': <String, Object>{},
          'user_metadata': <String, Object>{},
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    await abrir(tester, RegistrarGranjaScreen(elegir: () async => 'terreno.pdf'));
    await tocar(tester, 'Enviar registro');
    expect(find.text('Campo obligatorio'), findsNWidgets(5));
    expect(find.text('Mínimo 6 caracteres'), findsOneWidget);
    expect(find.text('Ingresa un número'), findsOneWidget);

    final campos = find.byType(TextFormField);
    await tester.enterText(campos.at(0), 'Ana Pérez');
    await tester.enterText(campos.at(1), 'ana@ejemplo.com');
    await tester.enterText(campos.at(2), 'secreta1');
    await tester.enterText(campos.at(3), 'Los Pinos');
    await tester.enterText(campos.at(4), '18,5');
    await tester.enterText(campos.at(5), 'SC-02418');
    await tocar(tester, 'Elegir archivo');
    expect(find.text('terreno.pdf ✓'), findsOneWidget);
    await tocar(tester, 'Enviar registro');

    expect(enviado['email'], 'ana@ejemplo.com');
    expect((enviado['data'] as Map)['superficie'], 18.5);
    expect(find.text('Recibimos el registro de Los Pinos.'), findsOneWidget);
  });

  testWidgets('Mi granja oculta al trabajador las opciones del dueño', (tester) async {
    entrarALosPinos(rol: RolMiembro.trabajador);
    await abrir(tester, const MiGranjaScreen());
    expect(find.text('Trabajador'), findsOneWidget);
    expect(find.text('Miembros del equipo  ›'), findsNothing);
    expect(find.text('Registrar otra granja'), findsOneWidget);
  });

  testWidgets('Mi granja permite reintentar si no carga', (tester) async {
    simularDatos(const {}, sinRed: true);
    await abrir(tester, const MiGranjaScreen());
    await tester.pump(const Duration(minutes: 1));
    await tester.pumpAndSettle();
    expect(find.text('–'), findsNWidgets(2));
    simularDatos(tablasEquipo);
    await tocar(tester, 'No se pudieron cargar los datos. Reintentar');
    expect(find.text('3'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('Mi granja muestra el equipo y solo opciones del Sprint 1', (tester) async {
    await abrir(tester, const MiGranjaScreen());
    expect(find.text('3'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('Miembros del equipo  ›'), findsOneWidget);
    expect(find.text('Registrar otra granja'), findsOneWidget);
    expect(find.text('Cerrar sesión'), findsOneWidget);
    expect(find.text('Mis granjas'), findsOneWidget);
    for (final fuera in ['Ganado e historial  ›', 'Reportes sanitarios  ›', 'Dar de baja un animal  ›', 'Avisos', 'Reportes']) {
      expect(find.text(fuera), findsNothing);
    }
  });

  testWidgets('Miembros muestra el equipo y la invitación pendiente', (tester) async {
    simularDatos(tablasEquipo);
    await abrir(tester, const MiGranjaScreen());
    await tocar(tester, 'Miembros del equipo  ›');
    expect(find.text('Equipo vinculado a Los Pinos.'), findsOneWidget);
    expect(find.text('Sofía Rojas · Veterinario'), findsOneWidget);
    expect(find.text('luis@ejemplo.com · Trabajador'), findsOneWidget, reason: 'sin nombre usa el correo');
    expect(find.text('Invitación pendiente'), findsOneWidget);
    expect(find.textContaining('maria@ejemplo.com · Trabajador'), findsOneWidget);
    await tocar(tester, 'Volver', atajo: true);
    expect(find.text('Mi granja'), findsOneWidget);
  });

  testWidgets('Miembros permite reintentar si no carga', (tester) async {
    simularDatos(const {}, sinRed: true);
    await abrir(tester, const MiembrosScreen());
    await tester.pump(const Duration(minutes: 1));
    await tester.pumpAndSettle();
    simularDatos(tablasEquipo);
    await tocar(tester, 'No se pudo cargar el equipo. Reintentar');
    expect(find.text('Sofía Rojas · Veterinario'), findsOneWidget);
  });

  testWidgets('Invitar valida el correo y guarda la invitación en Supabase', (tester) async {
    final pedidos = <http.BaseRequest>[];
    simularDatos(tablasEquipo, pedidos: pedidos);
    await abrir(tester, const MiembrosScreen());
    await tocar(tester, 'Invitar persona');
    await tester.enterText(find.byType(TextFormField), 'no-es-correo');
    await tocar(tester, 'Enviar invitación');
    expect(find.text('Correo no válido'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), 'Sofia@ejemplo.com');
    await tocar(tester, 'Enviar invitación');
    expect(find.text('Esa persona ya es miembro de la granja'), findsOneWidget);
    expect(pedidos.where((p) => p.method == 'POST'), isEmpty);

    await tester.enterText(find.byType(TextFormField), ' Nueva@ejemplo.com ');
    await tocar(tester, 'Enviar invitación');
    final guardado = jsonDecode((pedidos.firstWhere((p) => p.method == 'POST') as http.Request).body) as Map<String, dynamic>;
    expect(guardado, {'granja_id': 'g1', 'correo': 'nueva@ejemplo.com', 'rol': 'veterinario'});
    final correo = pedidos.singleWhere((p) => p.url.path.endsWith('dynamic-action')) as http.Request;
    expect(jsonDecode(correo.body), {'invitacion_id': 'nueva'});
    expect(find.text('Invitación enviada a nueva@ejemplo.com'), findsOneWidget);
    expect(find.text('Equipo vinculado a Los Pinos.'), findsOneWidget);
  });

  testWidgets('Invitar conserva la invitación si el correo falla', (tester) async {
    simularDatos(tablasEquipo, correoFalla: true);
    await abrir(tester, const MiembrosScreen());
    await tocar(tester, 'Invitar persona');
    await tester.enterText(find.byType(TextFormField), 'nueva@ejemplo.com');
    await tocar(tester, 'Enviar invitación');
    expect(
      find.text('La invitación quedó guardada, pero el correo no salió: El envío de correos no está configurado. Reenvíala desde Miembros'),
      findsOneWidget,
    );
    expect(find.text('Equipo vinculado a Los Pinos.'), findsOneWidget);
  });

  testWidgets('Reenviar envía el correo de las invitaciones pendientes', (tester) async {
    final pedidos = <http.BaseRequest>[];
    simularDatos(tablasEquipo, pedidos: pedidos);
    await abrir(tester, const MiembrosScreen());
    await tocar(tester, 'Reenviar invitación');
    final correo = pedidos.singleWhere((p) => p.url.path.endsWith('dynamic-action')) as http.Request;
    expect(jsonDecode(correo.body), {'invitacion_id': 'i1'});
    expect(find.text('Se reenviaron 1 de 1 invitaciones'), findsOneWidget);
  });

  testWidgets('Reenviar avisa si el correo falla o no hay pendientes', (tester) async {
    simularDatos(tablasEquipo, correoFalla: true);
    await abrir(tester, const MiembrosScreen());
    await tocar(tester, 'Reenviar invitación');
    expect(find.text('Solo se reenviaron 0 de 1 invitaciones: El envío de correos no está configurado'), findsOneWidget);

    simularDatos({'vinculaciones': tablasEquipo['vinculaciones']!});
    await abrir(tester, const SizedBox());
    await abrir(tester, const MiembrosScreen());
    await tocar(tester, 'Reenviar invitación');
    expect(find.text('No hay invitaciones pendientes'), findsOneWidget);
  });

  testWidgets('Invitar avisa si la invitación ya existe', (tester) async {
    simularDatos(tablasEquipo, errorAlGuardar: '23505');
    await abrir(tester, const InvitarScreen());
    await tester.enterText(find.byType(TextFormField), 'maria@ejemplo.com');
    await tocar(tester, 'Enviar invitación');
    expect(find.text('Esa persona ya tiene una invitación pendiente'), findsOneWidget);
  });

  testWidgets('Registrar otra granja avisa si falla', (tester) async {
    simularDatos(const {}, errorAlGuardar: '42501');
    await abrir(tester, RegistrarOtraGranjaScreen(elegir: () async => 'adjunto.pdf'));
    final campos = find.byType(TextFormField);
    await tester.enterText(campos.at(0), 'Santa Rosa');
    await tester.enterText(campos.at(1), '12');
    await tester.enterText(campos.at(2), 'SC-02419');
    await tocar(tester, 'Elegir archivo');
    await tocar(tester, 'Enviar registro');
    expect(find.text('No se pudo registrar la granja'), findsOneWidget);
    expect(find.text('Registrar otra granja'), findsOneWidget);
  });

  testWidgets('Registrar otra granja valida y guarda el registro', (tester) async {
    final pedidos = <http.BaseRequest>[];
    simularDatos(const {}, pedidos: pedidos);
    await abrir(tester, RegistrarOtraGranjaScreen(elegir: () async => 'adjunto.pdf'));
    await tocar(tester, 'Enviar registro');
    expect(find.text('Campo obligatorio'), findsNWidgets(3));

    final campos = find.byType(TextFormField);
    await tester.enterText(campos.at(0), 'Santa Rosa');
    await tester.enterText(campos.at(1), '12');
    await tester.enterText(campos.at(2), 'SC-02419');
    await tocar(tester, 'Elegir archivo');
    await tocar(tester, 'Enviar registro');
    final rpc = pedidos.singleWhere((p) => p.url.path.endsWith('registrar_granja')) as http.Request;
    expect(jsonDecode(rpc.body), {
      'p_nombre': 'Santa Rosa',
      'p_hectareas': 12,
      'p_runsa': 'SC-02419',
      'p_documentos': 'adjunto.pdf',
    });
  });

  final santaRosa = {
    ...filaLosPinos,
    'id': 'g2',
    'nombre': 'Santa Rosa',
    'hectareas': 12.5,
    'confirmada': false,
    'vinculaciones': [
      {
        'rol': 'dueno',
        'cuentas': {'nombre': 'Ana Pérez', 'identificador': 'ana@ejemplo.com'},
      },
    ],
  };

  testWidgets('Administración muestra el dueño, abre la solicitud y la confirma', (tester) async {
    final pedidos = <http.BaseRequest>[];
    simularDatos({
      'granjas': [santaRosa],
    }, pedidos: pedidos);
    await abrir(tester, const AdministracionScreen());
    expect(find.text('1 granja por confirmar'), findsOneWidget);
    expect(find.text('Dueño: Ana Pérez · ana@ejemplo.com\nRUNSA: SC-02418'), findsOneWidget);
    expect(find.text('Mis granjas'), findsNothing);
    final lista = pedidos.singleWhere((p) => p.url.pathSegments.last == 'granjas');
    expect(lista.url.queryParameters['confirmada'], 'eq.false');
    expect(lista.url.queryParameters['select'], contains('vinculaciones'));

    await tocar(tester, 'Santa Rosa · Pendiente  ›');
    expect(find.text('Confirmar granja'), findsOneWidget);
    expect(find.text('Dueño: Ana Pérez · ana@ejemplo.com'), findsOneWidget);
    expect(find.text('Superficie: 12.50 ha'), findsOneWidget);
    expect(find.text('terreno.pdf · Archivo adjunto a la solicitud'), findsOneWidget);

    simularDatos({'granjas': const <Object>[]}, pedidos: pedidos);
    await tocar(tester, 'Confirmar registro');
    final rpc = pedidos.singleWhere((p) => p.url.path.endsWith('confirmar_granja')) as http.Request;
    expect(jsonDecode(rpc.body), {'p_granja': 'g2'});
    expect(find.text('Santa Rosa quedó confirmada'), findsOneWidget);
    expect(find.text('0 granjas por confirmar'), findsOneWidget);
    expect(find.text('No hay solicitudes pendientes.'), findsOneWidget);
  });

  testWidgets('Administración avisa si el dueño no es visible, si no puede confirmar o si no carga', (tester) async {
    simularDatos({
      'granjas': [
        {...santaRosa, 'vinculaciones': const <Object>[]},
      ],
    }, errorAlGuardar: '42501');
    await abrir(tester, const AdministracionScreen());
    expect(find.text('Dueño: No disponible\nRUNSA: SC-02418'), findsOneWidget);
    await tocar(tester, 'Santa Rosa · Pendiente  ›');
    await tocar(tester, 'Confirmar registro');
    expect(find.text('No se pudo confirmar la granja'), findsOneWidget);
    expect(find.text('Confirmar granja'), findsOneWidget);
    await tocar(tester, 'Volver');
    expect(find.text('1 granja por confirmar'), findsOneWidget);

    simularDatos(const {}, sinRed: true);
    await abrir(tester, const SizedBox());
    await abrir(tester, const AdministracionScreen());
    await tester.pump(const Duration(minutes: 1));
    await tester.pumpAndSettle();
    simularDatos({
      'granjas': [santaRosa],
    });
    await tocar(tester, 'No se pudieron cargar las granjas. Reintentar');
    expect(find.text('Santa Rosa · Pendiente  ›'), findsOneWidget);
  });

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
