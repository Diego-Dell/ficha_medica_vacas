import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:ficha_medica_vacas/logic/granjas.dart';
import 'package:ficha_medica_vacas/logic/sesion.dart';
import 'package:ficha_medica_vacas/main.dart';
import 'package:ficha_medica_vacas/models/miembro.dart';
import 'package:ficha_medica_vacas/screens/acceso_general/nueva_contrasena_screen.dart';
import 'package:ficha_medica_vacas/screens/acceso_general/seleccionar_granja_screen.dart';
import 'package:ficha_medica_vacas/screens/administrador/administracion_screen.dart';
import 'package:ficha_medica_vacas/screens/dueno_granja/mi_granja_screen.dart';
import 'package:ficha_medica_vacas/screens/trabajador/cuidados_hoy_screen.dart';
import 'package:ficha_medica_vacas/screens/veterinario/seguimiento_veterinario_screen.dart';

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
    expect(find.image(const AssetImage('assets/images/login_vaca.png')), findsOneWidget);
    expect(find.image(const AssetImage('assets/images/logo.png')), findsOneWidget);
    expect(find.text('Correo electrónico'), findsOneWidget);
    expect(find.text('Contraseña'), findsOneWidget);
  });

  testWidgets('recuperar acceso envía el correo y permite volver', (tester) async {
    late Map<String, dynamic> enviado;
    late Uri enlace;
    Sesion.instance.auth = cliente((pedido) async {
      enviado = jsonDecode(pedido.body) as Map<String, dynamic>;
      enlace = pedido.url;
      return http.Response('{}', 200, headers: {'content-type': 'application/json'});
    });
    await tester.pumpWidget(const FichaMedicaApp());
    await tocar(tester, 'Olvidé mi contraseña');
    await tester.pumpAndSettle();
    expect(find.text('Recuperar contraseña'), findsOneWidget);
    await tocar(tester, 'Enviar enlace');
    await tester.pump();
    expect(find.text('Campo obligatorio'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), ' $correo ');
    await tocar(tester, 'Enviar enlace');
    await tester.pumpAndSettle();
    expect(enviado['email'], correo);
    expect(enlace.queryParameters['redirect_to'], 'vetlink://restablecer');
    expect(find.text('Si el correo tiene una cuenta, te enviamos el enlace'), findsOneWidget);
    await tocar(tester, '‹ Volver');
    await tester.pumpAndSettle();
    expect(find.text('Bienvenido a VetLink'), findsOneWidget);
  });

  testWidgets('la persona invitada crea su cuenta sin datos de granja', (tester) async {
    late Map<String, dynamic> enviado;
    Sesion.instance.auth = cliente((pedido) async {
      enviado = jsonDecode(pedido.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode({
          'id': '2',
          'aud': 'authenticated',
          'email': correo,
          'created_at': '2026-11-04T00:00:00Z',
          'app_metadata': <String, Object>{},
          'user_metadata': <String, Object>{},
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    await tester.pumpWidget(const FichaMedicaApp());
    await tocar(tester, 'Me invitaron: crear cuenta');
    await tester.pumpAndSettle();
    Future<void> tocarCrear() async {
      final boton = find.widgetWithText(FilledButton, 'Crear cuenta');
      await tester.ensureVisible(boton);
      await tester.pumpAndSettle();
      await tester.tap(boton);
      await tester.pumpAndSettle();
    }

    await tocarCrear();
    expect(find.text('Campo obligatorio'), findsNWidgets(2));
    expect(find.text('Mínimo 6 caracteres'), findsOneWidget);

    final campos = find.byType(TextFormField);
    await tester.enterText(campos.at(0), ' Sofía Rojas ');
    await tester.enterText(campos.at(1), ' $correo ');
    await tester.enterText(campos.at(2), 'secreta1');
    await tocarCrear();
    expect(enviado['email'], correo);
    expect(enviado['data'], {'nombre': 'Sofía Rojas'});
    expect(find.text('Confirma tu correo e inicia sesión para aceptar la invitación'), findsOneWidget);
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
    expect(find.text('$correo · Así está el equipo de Los Pinos.'), findsOneWidget);
    expect(Sesion.instance.iniciada, isTrue);
  });

  testWidgets('pregunta por la invitación y la acepta', (tester) async {
    Sesion.instance.auth = cliente((_) async => sesionValida());
    final pedidos = <http.BaseRequest>[];
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
    final rpc = pedidos.singleWhere((p) => p.url.path.endsWith('aceptar_invitacion')) as http.Request;
    expect(jsonDecode(rpc.body), {'p_invitacion': 'i1'});
    expect(find.byType(CuidadosHoyScreen), findsOneWidget);
    expect(find.byType(MiGranjaScreen), findsNothing);
    expect(find.text('Mi granja'), findsOneWidget);
    expect(find.text('Miembros del equipo  ›'), findsNothing);
  });

  testWidgets('el veterinario entra a su panel con la granja confirmada', (tester) async {
    Sesion.instance.auth = cliente((_) async => sesionValida());
    simularDatos({
      'vinculaciones': [
        {'rol': 'veterinario', 'granjas': {...filaLosPinos, 'confirmada': false}},
        {'rol': 'veterinario', 'granjas': filaLosPinos},
      ],
    });
    await ingresar(tester, 'clave');
    expect(find.byType(SeguimientoVeterinarioScreen), findsOneWidget);
    expect(find.byType(MiGranjaScreen), findsNothing);
    expect(tester.widget<SeguimientoVeterinarioScreen>(find.byType(SeguimientoVeterinarioScreen)).granja, 'Los Pinos');
  });

  testWidgets('el administrador entra sin granja y sin aceptar invitaciones', (tester) async {
    Sesion.instance.auth = cliente((_) async => sesionValida());
    final pedidos = <http.BaseRequest>[];
    simularDatos({
      'es_administrador': true,
      'granjas': [
        {...filaLosPinos, 'confirmada': false},
      ],
    }, pedidos: pedidos);
    await ingresar(tester, 'clave');
    expect(find.byType(AdministracionScreen), findsOneWidget);
    expect(find.byType(MiGranjaScreen), findsNothing);
    expect(find.text('Tu cuenta todavía no tiene una granja'), findsNothing);
    expect(pedidos.map((p) => p.url.pathSegments.last), ['es_administrador', 'granjas']);
    expect(find.text('1 granja por confirmar'), findsOneWidget);
  });

  testWidgets('si no se puede verificar el rol no abre ningún panel', (tester) async {
    Sesion.instance.auth = cliente((_) async => sesionValida());
    simularDatos(const {}, errorAlGuardar: '42501');
    await ingresar(tester, 'clave');
    expect(find.byType(AdministracionScreen), findsNothing);
    expect(find.byType(MiGranjaScreen), findsNothing);
    expect(find.text('Bienvenido a VetLink'), findsOneWidget);
  });

  testWidgets('el trabajador entra directamente a su panel', (tester) async {
    Sesion.instance.auth = cliente((_) async => sesionValida());
    simularDatos({
      'vinculaciones': [
        {'rol': 'trabajador', 'granjas': filaLosPinos},
      ],
    });
    await ingresar(tester, 'clave');
    expect(find.byType(CuidadosHoyScreen), findsOneWidget);
    expect(find.byType(MiGranjaScreen), findsNothing);
  });

  testWidgets('la invitación se puede dejar para después', (tester) async {
    Sesion.instance.auth = cliente((_) async => sesionValida());
    final pedidos = <http.BaseRequest>[];
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
    expect(find.text('No se pudieron cargar tus granjas. Intenta de nuevo'), findsOneWidget);
  });

  testWidgets('con varias granjas pide elegir y al cambiar recupera el rol de cada una', (tester) async {
    Sesion.instance.auth = cliente((_) async => sesionValida());
    const cuenta = {'nombre': 'Ana Pérez', 'identificador': correo};
    simularDatos({
      'vinculaciones': [
        {'rol': 'veterinario', 'granjas': {...filaLosPinos, 'id': 'g2', 'nombre': 'Santa Rosa'}, 'cuentas': cuenta},
        {'rol': 'dueno', 'granjas': filaLosPinos, 'cuentas': cuenta},
        {'rol': 'trabajador', 'granjas': {...filaLosPinos, 'id': 'g3', 'nombre': 'El Ceibo', 'confirmada': false}, 'cuentas': cuenta},
      ],
    });
    await ingresar(tester, 'clave');
    expect(find.byType(SeleccionarGranjaScreen), findsOneWidget);
    expect(find.text('Veterinario · Confirmada'), findsOneWidget);
    expect(find.textContaining('Dueño · '), findsOneWidget);
    expect(find.text('Trabajador · En revisión'), findsOneWidget);

    await tocar(tester, 'Santa Rosa');
    await tester.pumpAndSettle();
    expect(tester.widget<SeguimientoVeterinarioScreen>(find.byType(SeguimientoVeterinarioScreen)).granja, 'Santa Rosa');
    expect(Granjas.instance.rol, RolMiembro.veterinario);

    await tocar(tester, 'Mis granjas');
    await tester.pumpAndSettle();
    expect(find.text('Veterinario · Granja actual'), findsOneWidget);
    await tocar(tester, 'Los Pinos');
    await tester.pumpAndSettle();
    expect(find.byType(MiGranjaScreen), findsOneWidget);
    expect(Granjas.instance.rol, RolMiembro.dueno);
    expect(find.text('Miembros del equipo  ›'), findsOneWidget);
    expect(find.byType(SeguimientoVeterinarioScreen), findsNothing);
    expect(find.byType(SeleccionarGranjaScreen), findsNothing);
  });

  testWidgets('cerrar sesión cierra la sesión en Supabase y vuelve al login', (tester) async {
    final rutas = <String>[];
    Sesion.instance.auth = cliente((pedido) async {
      rutas.add(pedido.url.path);
      return pedido.url.path.endsWith('logout') ? http.Response('', 204) : sesionValida();
    });
    simularDatos({
      'vinculaciones': [
        {'rol': 'trabajador', 'granjas': filaLosPinos},
      ],
    });
    await ingresar(tester, 'clave');
    expect(find.byType(CuidadosHoyScreen), findsOneWidget);
    await tocar(tester, 'Cerrar sesión');
    await tester.pumpAndSettle();
    expect(rutas.where((ruta) => ruta.endsWith('logout')), hasLength(1));
    expect(Sesion.instance.iniciada, isFalse);
    expect(find.text('Bienvenido a VetLink'), findsOneWidget);
  });

  // 4. Abre Nueva contraseña con una sesión iniciada, como si llegara desde el enlace del correo.
  Future<List<http.Request>> abrirNuevaContrasena(WidgetTester tester, {String? errorAlGuardar}) async {
    final pedidos = <http.Request>[];
    Sesion.instance.auth = cliente((pedido) async {
      pedidos.add(pedido);
      if (pedido.url.path.endsWith('logout')) return http.Response('', 204);
      if (pedido.method == 'PUT') {
        if (errorAlGuardar != null) return error(422, errorAlGuardar);
        return http.Response(
          jsonEncode((jsonDecode(sesionValida().body) as Map<String, dynamic>)['user']),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return sesionValida();
    });
    await tester.runAsync(() => Sesion.instance.iniciar(correo, 'vieja'));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NuevaContrasenaScreen())),
              child: const Text('inicio'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('inicio'));
    await tester.pumpAndSettle();
    return pedidos;
  }

  testWidgets('Nueva contraseña valida, guarda la clave y vuelve al login', (tester) async {
    final pedidos = await abrirNuevaContrasena(tester);
    await tocar(tester, 'Guardar contraseña');
    await tester.pump();
    expect(find.text('Campo obligatorio'), findsNWidgets(2));
    await tester.enterText(find.byType(TextFormField).first, 'abcdefgh');
    await tester.enterText(find.byType(TextFormField).last, 'distinta');
    await tocar(tester, 'Guardar contraseña');
    await tester.pump();
    expect(find.text('Las contraseñas no coinciden'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).last, 'abcdefgh');
    await tester.tap(find.byTooltip('Mostrar contraseña'));
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField).first).obscureText, isFalse);
    await tocar(tester, 'Guardar contraseña');
    await tester.pumpAndSettle();
    final guardado = pedidos.singleWhere((p) => p.method == 'PUT');
    expect((jsonDecode(guardado.body) as Map<String, dynamic>)['password'], 'abcdefgh');
    expect(pedidos.where((p) => p.url.path.endsWith('logout')), hasLength(1));
    expect(find.text('Tu contraseña se actualizó. Iniciá sesión con la nueva'), findsOneWidget);
    expect(find.text('inicio'), findsOneWidget);
  });

  testWidgets('Nueva contraseña avisa si es igual a la anterior', (tester) async {
    await abrirNuevaContrasena(tester, errorAlGuardar: 'same_password');
    await tester.enterText(find.byType(TextFormField).first, 'abcdefgh');
    await tester.enterText(find.byType(TextFormField).last, 'abcdefgh');
    await tocar(tester, 'Guardar contraseña');
    await tester.pumpAndSettle();
    expect(find.text('La nueva contraseña debe ser distinta de la anterior'), findsOneWidget);
    expect(find.byType(NuevaContrasenaScreen), findsOneWidget);
  });
}
