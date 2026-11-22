import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:ficha_medica_vacas/logic/documentos.dart';

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
  await tester.pumpWidget(MaterialApp(key: UniqueKey(), home: pantalla));
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
  if (boton == 'Enviar invitación' || boton == 'Reenviar invitación' || boton == 'Enviar registro') {
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
  TestWidgetsFlutterBinding.ensureInitialized();
  const documento = 'pendiente/0123456789abcdef0123456789abcdef/terreno.pdf';
  late Directory temporal;
  setUp(() async {
    temporal = await Directory.systemTemp.createTemp('vetlink-registro-test-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'), (_) async => temporal.path);
    final archivo = await Documentos.local(documento);
    await archivo.parent.create(recursive: true);
    await archivo.writeAsString('%PDF-1.4 prueba');
    entrarALosPinos();
    simularDatos(tablasEquipo);
  });

  tearDown(() async { await temporal.delete(recursive: true); });

  for (final correoEnviado in [true, false]) {
  testWidgets('Registrar mi granja conserva la solicitud con correo enviado: $correoEnviado', (tester) async {
    late String enviado;
    Sesion.instance.registroCliente = MockClient((pedido) async {
      enviado = pedido.body;
      return http.Response(jsonEncode({'id':'g-nueva','documento':'storage/dueno/g-nueva/terreno.pdf','correoEnviado':correoEnviado}),200);
    });
    addTearDown(() => Sesion.instance.registroCliente = null);
    await abrir(tester, RegistrarGranjaScreen(elegir: () async => documento));
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
    await tocar(tester, 'Elegir PDF (hasta 10 MB)');
    expect(find.text('terreno.pdf ✓'), findsOneWidget);
    await tocar(tester, 'Enviar registro');

    expect(enviado, contains('ana@ejemplo.com'));
    expect(enviado, contains('%PDF-1.4'));
    expect(enviado, contains('18.5'));
    expect(find.text('Granja en revisión'), findsOneWidget);
    expect(find.text('Recibimos el registro de Los Pinos.'), findsOneWidget);
    expect(Sesion.instance.granjaRegistrada?.id, 'g-nueva');
    if (!correoEnviado) {
      expect(find.textContaining('La solicitud y el PDF están guardados'), findsOneWidget);
      final pedidos = <http.Request>[];
      Sesion.instance.auth = cliente((r) async {
        pedidos.add(r);
        return http.Response('{}', 200, headers: {'content-type':'application/json'});
      });
      await tocar(tester, 'Reenviar correo de confirmación');
      expect(pedidos.single.url.path, endsWith('/resend'));
      expect(jsonDecode(pedidos.single.body)['email'],'ana@ejemplo.com');
      expect(jsonDecode(pedidos.single.body)['type'],'signup');
      expect(pedidos.single.url.queryParameters['redirect_to'],'vetlink://confirmar');
      expect(find.text('Granja en revisión'),findsOneWidget);
      expect(find.textContaining('La solicitud y el PDF están guardados'),findsNothing);
      expect(Sesion.instance.granjaRegistrada?.id,'g-nueva');
    } else {
      expect(find.text('Reenviar correo de confirmación'),findsNothing);
    }
  });
  }

  testWidgets('Si falla el reenvío, conserva la solicitud y permite reintentar', (tester) async {
    Sesion.instance.auth=cliente((_) async => http.Response(
      jsonEncode({'code':429,'error_code':'over_email_send_rate_limit','msg':'limite'}),429,
      headers:{'content-type':'application/json'}));
    await abrir(tester,const GranjaRevisionScreen(granja:losPinos,
      correoConfirmacion:'ana@ejemplo.com',correoEnviado:false));
    await tocar(tester,'Reenviar correo de confirmación');
    expect(find.text('Se enviaron demasiados correos. Intentá más tarde'),findsOneWidget);
    expect(find.text('Reenviar correo de confirmación'),findsOneWidget);
    expect(find.text('Documentación recibida'),findsOneWidget);
  });

  testWidgets('Mi granja oculta al trabajador las opciones del dueño', (tester) async {
    entrarALosPinos(rol: RolMiembro.trabajador);
    await abrir(tester, const MiGranjaScreen());
    expect(find.text('Los Pinos · Trabajador'), findsOneWidget);
    expect(find.text('Equipo'), findsNothing);
    expect(find.text('Registrar otra granja'), findsNothing);
    expect(find.text('Reportes'), findsNothing);
    await tester.tap(find.byTooltip('Cambiar de granja'));
    await tester.pumpAndSettle();
    expect(find.text('Registrar otra granja'), findsOneWidget);
  });

  testWidgets('Mi granja muestra resumen y equipo, una sola ruta por sección y registra otra granja', (tester) async {
    await abrir(tester, const MiGranjaScreen());
    expect(find.text('Operaciones de la granja'), findsOneWidget);
    expect(find.text('Equipo'), findsOneWidget);
    expect(find.text('Registrar otra granja'), findsNothing);
    // 1. Ficha, baja y búsqueda viven en la pestaña Ganado; cerrar sesión en Perfil.
    for (final repetida in ['Ficha', 'Baja del animal', 'Búsqueda', 'Cerrar sesión']) {
      expect(find.text(repetida), findsNothing, reason: repetida);
    }
    for (final pestana in ['Inicio', 'Ganado', 'Perfil']) {
      expect(find.text(pestana), findsOneWidget);
    }
    await tester.tap(find.byTooltip('Cambiar de granja'));
    await tester.pumpAndSettle();
    expect(find.text('Registrar otra granja'), findsOneWidget);
    await tocar(tester, 'Registrar otra granja');
    expect(find.byType(RegistrarOtraGranjaScreen), findsOneWidget);
  });

  testWidgets('Miembros muestra el equipo y la invitación pendiente', (tester) async {
    simularDatos(tablasEquipo);
    await abrir(tester, const MiGranjaScreen());
    await tocar(tester, 'Equipo');
    expect(find.text('Equipo vinculado a Los Pinos.'), findsOneWidget);
    expect(find.text('Sofía Rojas · Veterinario'), findsOneWidget);
    expect(find.text('luis@ejemplo.com · Trabajador'), findsOneWidget, reason: 'sin nombre usa el correo');
    expect(find.text('Invitación pendiente'), findsOneWidget);
    expect(find.textContaining('maria@ejemplo.com · Trabajador'), findsOneWidget);
    await tester.tap(find.byTooltip('Volver'));
    await tester.pumpAndSettle();
    expect(find.byType(MiGranjaScreen), findsOneWidget);
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
    await abrir(tester, RegistrarOtraGranjaScreen(elegir: () async => documento));
    final campos = find.byType(TextFormField);
    await tester.enterText(campos.at(0), 'Santa Rosa');
    await tester.enterText(campos.at(1), '12');
    await tester.enterText(campos.at(2), 'SC-02419');
    await tocar(tester, 'Elegir PDF (hasta 10 MB)');
    await tocar(tester, 'Enviar registro');
    expect(find.text('No se completó el registro. Revisá la conexión y reintentá subir el PDF'), findsOneWidget);
    expect(find.text('Registrar otra granja'), findsOneWidget);
  });

  testWidgets('Registrar otra granja valida y guarda el registro', (tester) async {
    final pedidos = <http.BaseRequest>[];
    simularDatos(const {}, pedidos: pedidos);
    await abrir(tester, RegistrarOtraGranjaScreen(elegir: () async => documento));
    await tocar(tester, 'Enviar registro');
    expect(find.text('Campo obligatorio'), findsNWidgets(3));

    final campos = find.byType(TextFormField);
    await tester.enterText(campos.at(0), 'Santa Rosa');
    await tester.enterText(campos.at(1), '12');
    await tester.enterText(campos.at(2), 'SC-02419');
    await tocar(tester, 'Elegir PDF (hasta 10 MB)');
    await tocar(tester, 'Enviar registro');
    final rpc = pedidos.singleWhere((p) => p.url.path.endsWith('registrar_granja')) as http.Request;
    expect(jsonDecode(rpc.body), {
      'p_nombre': 'Santa Rosa',
      'p_hectareas': 12,
      'p_runsa': 'SC-02419',
      'p_documentos': 'storage/${Sesion.instance.id}/01234567-89ab-cdef-0123-456789abcdef/terreno.pdf',
    });
  });

  final santaRosa = {
    ...filaLosPinos,
    'id': 'g2',
    'nombre': 'Santa Rosa',
    'documentos_terreno': 'storage/dueno/g2/terreno.pdf',
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
    expect(find.text('granja por confirmar'), findsOneWidget);
    expect(find.text('Mis granjas'), findsNothing);
    final lista = pedidos.singleWhere((p) => p.url.pathSegments.last == 'granjas');
    expect(lista.url.queryParameters['confirmada'], 'eq.false');
    expect(lista.url.queryParameters['select'], contains('vinculaciones'));

    await tocar(tester, 'Santa Rosa');
    expect(find.text('Dueño: Ana Pérez · ana@ejemplo.com\nRUNSA: SC-02418'), findsOneWidget);
    await tocar(tester, 'Santa Rosa · Pendiente');
    expect(find.text('Confirmar granja'), findsOneWidget);
    expect(find.text('Dueño: Ana Pérez · ana@ejemplo.com'), findsOneWidget);
    expect(find.text('Superficie: 12.50 ha'), findsOneWidget);
    expect(find.text('Abrir documento'), findsOneWidget);

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
    await tocar(tester, 'Santa Rosa');
    expect(find.text('Dueño: No disponible\nRUNSA: SC-02418'), findsOneWidget);
    await tocar(tester, 'Santa Rosa · Pendiente');
    await tocar(tester, 'Confirmar registro');
    expect(find.text('No se pudo confirmar la granja'), findsOneWidget);
    expect(find.text('Confirmar granja'), findsOneWidget);
    await tester.tap(find.byTooltip('Volver'));
    await tester.pumpAndSettle();
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
    await tocar(tester, 'Santa Rosa');
    expect(find.text('Santa Rosa · Pendiente'), findsOneWidget);
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
