import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:ficha_medica_vacas/logic/sesion.dart';
import 'package:ficha_medica_vacas/main.dart';

const correo = 'ana@ejemplo.com';

/// Cliente de Supabase que responde sin salir a internet.
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

/// La pantalla de prueba es más baja que un celular: hay que desplazarse hasta el botón.
Future<void> tocar(WidgetTester tester, String boton) async {
  await tester.ensureVisible(find.text(boton));
  await tester.pumpAndSettle();
  await tester.tap(find.text(boton));
}

void main() {
  test('Sesion siempre devuelve la misma instancia', () {
    expect(identical(Sesion.instance, Sesion.instance), isTrue);
  });

  // El Singleton conserva su estado entre pruebas: esta debe ir antes de asignar un cliente.
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
    await ingresar(tester, 'clave');
    expect(enviado['email'], correo);
    expect(find.text('Bienvenido, $correo'), findsOneWidget);
    expect(Sesion.instance.iniciada, isTrue);
  });
}
