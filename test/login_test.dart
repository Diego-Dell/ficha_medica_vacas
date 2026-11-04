import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:ficha_medica_vacas/logic/sesion.dart';
import 'package:ficha_medica_vacas/main.dart';

import 'apoyo.dart';

const correo = 'ana@ejemplo.com';

/// 1. Crea un cliente de Supabase que responde sin salir a internet.
GoTrueClient cliente(MockClientHandler respuesta) => GoTrueClient(
      url: 'https://prueba.supabase.co/auth/v1',
      httpClient: MockClient(respuesta),
      autoRefreshToken: false,
      flowType: AuthFlowType.implicit,
    );

http.Response error(int estado, String codigo) => http.Response(
      jsonEncode({'code': estado, 'error_code': codigo, 'msg': codigo}),
      estado,
      headers: {'content-type': 'application/json'},
    );

http.Response sesionValida() {
  String parte(Map<String, Object> datos) => base64Url.encode(utf8.encode(jsonEncode(datos))).replaceAll('=', '');
  final vence = DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000;
  return http.Response(
    jsonEncode({
      'access_token': '${parte({'alg': 'HS256'})}.${parte({'sub': '1', 'exp': vence})}.firma',
      'token_type': 'bearer',
      'expires_in': 3600,
      'expires_at': vence,
      'refresh_token': 'renovar',
      'user': {
        'id': '1',
        'aud': 'authenticated',
        'email': correo,
        'created_at': '2026-11-01T00:00:00Z',
        'app_metadata': <String, Object>{},
        'user_metadata': <String, Object>{},
      },
    }),
    200,
    headers: {'content-type': 'application/json'},
  );
}

Future<void> ingresar(WidgetTester tester, String contrasena) async {
  await tester.pumpWidget(const FichaMedicaApp());
  await tester.enterText(find.byType(TextFormField).at(0), ' $correo ');
  await tester.enterText(find.byType(TextFormField).at(1), contrasena);
  await tocar(tester, 'Iniciar sesión');
  await tester.pumpAndSettle();
}

/// 2. Se desplaza hasta el botón y lo toca, porque la pantalla de prueba es más baja que un celular.
Future<void> tocar(WidgetTester tester, String boton) async {
  await tester.ensureVisible(find.text(boton));
  await tester.pumpAndSettle();
  await tester.tap(find.text(boton));
}

void main() {
  test('Sesion siempre devuelve la misma instancia', () {
    expect(identical(Sesion.instance, Sesion.instance), isTrue);
  });

  // 3. Prueba la app sin configurar antes de asignar un cliente, porque el Singleton conserva su estado.
  testWidgets('sin configuración no permite entrar', (tester) async {
    await ingresar(tester, 'clave');
    expect(find.text('La app no está configurada'), findsOneWidget);
  });

  testWidgets('pide completar los campos', (tester) async {
    await tester.pumpWidget(const FichaMedicaApp());
    await tocar(tester, 'Iniciar sesión');
    await tester.pump();
    expect(find.text('Campo obligatorio'), findsNWidgets(2));
  });

  testWidgets('muestra el diseño de VetLink', (tester) async {
    await tester.pumpWidget(const FichaMedicaApp());
    expect(find.text('Bienvenido a VetLink'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('ana@ejemplo.com'), findsOneWidget);
  });

  testWidgets('recuperar acceso envía el correo y permite volver', (tester) async {
    late Map<String, dynamic> enviado;
    Sesion.instance.auth = cliente((pedido) async {
      enviado = jsonDecode(pedido.body) as Map<String, dynamic>;
      return http.Response('{}', 200, headers: {'content-type': 'application/json'});
    });
    await tester.pumpWidget(const FichaMedicaApp());
    await tocar(tester, 'Olvidé mi contraseña');
    await tester.pumpAndSettle();
    expect(find.text('Recuperar acceso'), findsOneWidget);
    await tocar(tester, 'Enviar enlace');
    await tester.pump();
    expect(find.text('Campo obligatorio'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), ' $correo ');
    await tocar(tester, 'Enviar enlace');
    await tester.pumpAndSettle();
    expect(enviado['email'], correo);
    expect(find.text('Si el correo tiene una cuenta, te enviamos el enlace'), findsOneWidget);
    await tocar(tester, 'Volver');
    await tester.pumpAndSettle();
    expect(find.text('Bienvenido a VetLink'), findsOneWidget);
  });

  testWidgets('rechaza credenciales incorrectas', (tester) async {
    Sesion.instance.auth = cliente((_) async => error(400, 'invalid_credentials'));
    await ingresar(tester, 'otra');
    expect(find.text('Correo o contraseña incorrectos'), findsOneWidget);
    expect(Sesion.instance.iniciada, isFalse);
  });

  testWidgets('avisa si el correo no está confirmado', (tester) async {
    Sesion.instance.auth = cliente((_) async => error(400, 'email_not_confirmed'));
    await ingresar(tester, 'clave');
    expect(find.text('Falta confirmar el correo'), findsOneWidget);
  });

  testWidgets('avisa si no hay conexión', (tester) async {
    Sesion.instance.auth = cliente((_) async => throw http.ClientException('sin red'));
    await ingresar(tester, 'clave');
    expect(find.text('No se pudo conectar. Revisa tu internet'), findsOneWidget);
    expect(Sesion.instance.iniciada, isFalse);
  });

  testWidgets('inicia sesión y envía el correo sin espacios', (tester) async {
    late Map<String, dynamic> enviado;
    Sesion.instance.auth = cliente((pedido) async {
      enviado = jsonDecode(pedido.body) as Map<String, dynamic>;
      return sesionValida();
    });
    simularDatos({
      'vinculaciones': [
        {'rol': 'dueno', 'granjas': filaLosPinos},
      ],
    });
    await ingresar(tester, 'clave');
    expect(enviado['email'], correo);
    expect(find.text('Mi granja'), findsOneWidget);
    expect(find.text('$correo · Así va el cuidado en Los Pinos.'), findsOneWidget);
    expect(Sesion.instance.iniciada, isTrue);
  });

  testWidgets('pregunta por la invitación y la acepta', (tester) async {
    Sesion.instance.auth = cliente((_) async => sesionValida());
    final pedidos = <http.Request>[];
    simularDatos({
      'invitaciones': [
        {'id': 'i1', 'correo': correo.toUpperCase(), 'rol': 'trabajador', 'enviada_en': '2026-11-01T12:00:00Z'},
        {'id': 'i2', 'correo': 'otra@ejemplo.com', 'rol': 'veterinario', 'enviada_en': '2026-11-01T12:00:00Z'},
      ],
      'vinculaciones': [
        {'rol': 'trabajador', 'granjas': filaLosPinos},
      ],
    }, pedidos: pedidos);
    await ingresar(tester, 'clave');
    expect(find.text('Te invitaron a una granja como Trabajador. ¿Quieres unirte?'), findsOneWidget);
    await tester.tap(find.text('Aceptar'));
    await tester.pumpAndSettle();
    final rpc = pedidos.singleWhere((p) => p.url.path.endsWith('aceptar_invitacion'));
    expect(jsonDecode(rpc.body), {'p_invitacion': 'i1'});
    expect(find.text('Mi granja'), findsOneWidget);
    expect(find.text('Miembros del equipo  ›'), findsNothing);
  });

  testWidgets('la invitación se puede dejar para después', (tester) async {
    Sesion.instance.auth = cliente((_) async => sesionValida());
    final pedidos = <http.Request>[];
    simularDatos({
      'invitaciones': [
        {'id': 'i1', 'correo': correo, 'rol': 'trabajador', 'enviada_en': '2026-11-01T12:00:00Z'},
      ],
    }, pedidos: pedidos);
    await ingresar(tester, 'clave');
    await tester.tap(find.text('Ahora no'));
    await tester.pumpAndSettle();
    expect(pedidos.where((p) => p.url.path.endsWith('aceptar_invitacion')), isEmpty);
    expect(find.text('Tu cuenta todavía no tiene una granja'), findsOneWidget);
  });

  testWidgets('una granja sin confirmar muestra Granja en revisión', (tester) async {
    Sesion.instance.auth = cliente((_) async => sesionValida());
    simularDatos({
      'vinculaciones': [
        {
          'rol': 'dueno',
          'granjas': {...filaLosPinos, 'confirmada': false},
        },
      ],
    });
    await ingresar(tester, 'clave');
    expect(find.text('Granja en revisión'), findsOneWidget);
  });

  testWidgets('avisa si la cuenta no tiene granjas', (tester) async {
    Sesion.instance.auth = cliente((_) async => sesionValida());
    simularDatos({'vinculaciones': const []});
    await ingresar(tester, 'clave');
    expect(find.text('Tu cuenta todavía no tiene una granja'), findsOneWidget);
    expect(find.text('Bienvenido a VetLink'), findsOneWidget);
  });

  testWidgets('avisa si no se pueden cargar las granjas', (tester) async {
    Sesion.instance.auth = cliente((_) async => sesionValida());
    simularDatos(const {}, sinRed: true);
    await ingresar(tester, 'clave');
    await tester.pump(const Duration(minutes: 1));
    await tester.pumpAndSettle();
    expect(find.text('No se pudieron cargar tus granjas. Intenta de nuevo'), findsOneWidget);
  });
}
