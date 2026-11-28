import 'dart:convert';
import 'dart:async';

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
import 'package:ficha_medica_vacas/screens/acceso_general/crear_cuenta_screen.dart';
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
    await tester.tap(find.byTooltip('Volver'));
    await tester.pumpAndSettle();
    expect(find.text('Bienvenido a VetLink'), findsOneWidget);
  });

  testWidgets('la persona invitada crea su cuenta sin datos de granja', (tester) async {
    late Map<String, dynamic> enviado;
    late Uri direccion;
    Sesion.instance.auth = cliente((pedido) async {
      enviado = jsonDecode(pedido.body) as Map<String, dynamic>;
      direccion = pedido.url;
      return http.Response(
        jsonEncode({
          'id': '2',
          'identities': [{'id':'identidad','user_id':'2','identity_id':'identidad','provider':'email'}],
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
    expect(find.text('Revisá tu correo y spam para confirmar la cuenta. Si ya tenías cuenta, iniciá sesión'), findsOneWidget);
    expect(direccion.queryParameters['redirect_to'], 'vetlink://confirmar');
    expect(find.text('Bienvenido a VetLink'), findsOneWidget);
  });

  testWidgets('una cuenta confirmada duplicada vuelve al login sin anunciar un correo nuevo', (tester) async {
    final pedidos = <http.Request>[];
    Sesion.instance.auth = cliente((pedido) async {
      pedidos.add(pedido);
      return http.Response(jsonEncode({'id':'duplicado','aud':'authenticated','email':correo,
        'created_at':'2026-11-01T00:00:00Z','app_metadata':{},'user_metadata':{},'identities':[]}),200,
        headers:{'content-type':'application/json'});
    });
    await tester.pumpWidget(const FichaMedicaApp());
    await tocar(tester,'Me invitaron: crear cuenta');
    await tester.pumpAndSettle();
    final campos=find.byType(TextFormField);
    await tester.enterText(campos.at(0),'Trabajador');
    await tester.enterText(campos.at(1),correo);
    await tester.enterText(campos.at(2),'prueba123');
    final boton=find.widgetWithText(FilledButton,'Crear cuenta');
    await tester.ensureVisible(boton);
    await tester.tap(boton);
    await tester.pumpAndSettle();
    expect(find.byType(CrearCuentaScreen),findsNothing);
    expect(find.text(Sesion.cuentaExistente),findsOneWidget);
    expect(find.text('Bienvenido a VetLink'),findsOneWidget);
    expect(pedidos.where((p)=>p.url.path.endsWith('signup')),hasLength(1));
    expect(pedidos.where((p)=>p.url.path.endsWith('resend')),isEmpty);
  });

  test('registro invitado informa el límite de correo sin anunciar éxito', () async {
    Sesion.instance.auth=cliente((_) async => error(429,'over_email_send_rate_limit'));
    expect(await Sesion.instance.crearCuentaInvitada('Trabajador',correo,'prueba123'),
      'Se enviaron demasiados correos. Intenta más tarde');
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

  testWidgets('El login permite reintentar la confirmación sin crear otra cuenta', (tester) async {
    final pedidos=<http.Request>[];
    Sesion.instance.auth=cliente((r) async {
      pedidos.add(r);
      return r.url.path.endsWith('/resend')
        ? http.Response('{}',200,headers:{'content-type':'application/json'})
        : error(400,'email_not_confirmed');
    });
    await ingresar(tester,'clave');
    await tester.tap(find.text('Reenviar correo'));
    await tester.pumpAndSettle();
    expect(pedidos.where((r)=>r.url.path.endsWith('/resend')),hasLength(1));
    expect(pedidos.where((r)=>r.url.path.endsWith('/signup')),isEmpty);
    expect(find.text('Se solicitó el correo de confirmación. Revisá tu correo y spam'),findsOneWidget);
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
    expect(find.byType(MiGranjaScreen), findsOneWidget);
    expect(find.text('Los Pinos · Dueño'), findsOneWidget);
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
    expect(find.text('Rol asignado: Trabajador'), findsOneWidget);
    await tester.tap(find.text('Aceptar invitación').last);
    await tester.pumpAndSettle();
    final rpc = pedidos.singleWhere((p) => p.url.path.endsWith('aceptar_invitacion')) as http.Request;
    expect(jsonDecode(rpc.body), {'p_invitacion': 'i1'});
    expect(find.byType(CuidadosHoyScreen), findsOneWidget);
    expect(find.byType(MiGranjaScreen), findsNothing);
    expect(find.text('Los Pinos · Trabajador'), findsOneWidget);
    expect(find.text('Equipo'), findsNothing);
  });

  testWidgets('si la invitación ya no está vigente avisa y sigue entrando', (tester) async {
    Sesion.instance.auth = cliente((_) async => sesionValida());
    simularDatos({
      'invitaciones': [
        {'id': 'i1', 'correo': correo, 'rol': 'trabajador', 'enviada_en': '2026-11-01T12:00:00Z'},
      ],
      'vinculaciones': [
        {'rol': 'trabajador', 'granjas': filaLosPinos},
      ],
    }, rpcQueFalla: 'aceptar_invitacion');
    await ingresar(tester, 'clave');
    await tester.tap(find.text('Aceptar invitación').last);
    await tester.pumpAndSettle();
    expect(find.text('La invitación ya no está vigente'), findsOneWidget);
    expect(find.byType(CuidadosHoyScreen), findsOneWidget);
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
    expect(pedidos.map((p) => p.url.pathSegments.last), ['es_administrador', 'resumen', 'granjas', 'cuentas']);
    expect(find.text('Por confirmar'), findsNWidgets(2));
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

    await tester.tap(find.byTooltip('Cambiar de granja'));
    await tester.pumpAndSettle();
    expect(find.text('Cambiar de granja'), findsOneWidget);
    await tocar(tester, 'Los Pinos');
    await tester.pumpAndSettle();
    expect(find.byType(MiGranjaScreen), findsOneWidget);
    expect(Granjas.instance.rol, RolMiembro.dueno);
    expect(find.text('Equipo'), findsOneWidget);
    expect(find.byType(SeguimientoVeterinarioScreen), findsNothing);
    expect(find.byType(SeleccionarGranjaScreen), findsNothing);
  });

  test('solo los enlaces con datos de sesión se entregan a Supabase', () {
    expect(Sesion.instance.recordarEnlace(Uri.parse('vetlink://confirmar?code=abc')), isTrue);
    expect(Sesion.instance.recordarEnlace(Uri.parse('vetlink://restablecer#error=access_denied')), isTrue);
    expect(Sesion.instance.recordarEnlace(Uri.parse('vetlink://invitacion')), isFalse);
  });

  testWidgets('la invitación al abrir la app cerrada muestra Crear cuenta', (tester) async {
    Sesion.instance.dejarDeEscucharEnlaces();
    Sesion.instance.auth = cliente((_) async => sesionValida());
    await Sesion.instance.atenderEnlace(Uri.parse('vetlink://invitacion'));
    await tester.pumpWidget(const FichaMedicaApp());
    await tester.pumpAndSettle();
    expect(find.byType(CrearCuentaScreen), findsOneWidget);
    expect(Sesion.instance.iniciada, isFalse);
  });

  testWidgets('la invitación avisa si está abierta la cuenta del dueño y permite conservarla', (tester) async {
    Sesion.instance.auth = cliente((_) async => sesionValida());
    simularDatos({'vinculaciones': [{'rol':'dueno','granjas':filaLosPinos}]});
    await ingresar(tester, 'clave');
    await Sesion.instance.atenderEnlace(Uri.parse('vetlink://invitacion'));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('Abrir invitación'), findsOneWidget);
    expect(find.textContaining('La sesión abierta es $correo'), findsOneWidget);
    await tester.tap(find.text('Volver').last);
    await tester.pumpAndSettle();
    expect(find.byType(MiGranjaScreen), findsOneWidget);
    expect(Sesion.instance.iniciada, isTrue);
  });

  testWidgets('Cambiar cuenta abre el registro invitado sin aceptar con la cuenta anterior', (tester) async {
    Sesion.instance.auth = cliente((_) async => sesionValida());
    final pedidos = <http.BaseRequest>[];
    simularDatos({'vinculaciones': [{'rol':'dueno','granjas':filaLosPinos}]},pedidos:pedidos);
    await ingresar(tester, 'clave');
    await Sesion.instance.atenderEnlace(Uri.parse('vetlink://invitacion'));
    await tester.pump();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cambiar cuenta'));
    await tester.pumpAndSettle();
    expect(find.byType(CrearCuentaScreen), findsOneWidget);
    expect(Sesion.instance.iniciada, isFalse);
    expect(pedidos.where((p)=>p.url.path.endsWith('aceptar_invitacion')),isEmpty);
  });

  testWidgets('el enlace con la sesión invitada muestra Aceptar invitación', (tester) async {
    Sesion.instance.auth = cliente((_) async => sesionValida());
    await tester.runAsync(()=>Sesion.instance.iniciar(correo, 'clave'));
    simularDatos({'invitaciones': [{'id':'i1','correo':correo,'rol':'veterinario',
      'enviada_en':'2026-11-01T12:00:00Z','granja_nombre':'Los Pinos'}]});
    await tester.pumpWidget(const FichaMedicaApp());
    await Sesion.instance.atenderEnlace(Uri.parse('vetlink://invitacion'));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('Rol asignado: Veterinario'),findsOneWidget);
    expect(find.text('Cambiar cuenta'),findsNothing);
  });

  testWidgets('confirmar al trabajador desde el login quieto programa la navegación y abre la invitación', (tester) async {
    Sesion.instance.auth = cliente((_) async => sesionValida());
    simularDatos({'invitaciones': [
      {'id':'i-trabajador','correo':correo,'rol':'trabajador','granja_nombre':'Los Pinos',
        'enviada_en':'2026-11-01T12:00:00Z'},
    ]});
    await tester.pumpWidget(const FichaMedicaApp());
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.runAsync(() => Sesion.instance.atenderEnlace(
      Uri.parse('vetlink://confirmar?token_hash=prueba_trabajador_quieto&type=email')));
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.pumpAndSettle();
    expect(find.text('Rol asignado: Trabajador'), findsOneWidget);
    expect(find.text('Aceptar invitación').last, findsOneWidget);
  });

  testWidgets('la confirmación recibida antes de montar el login también abre la invitación', (tester) async {
    Sesion.instance.dejarDeEscucharEnlaces();
    Sesion.instance.auth = cliente((_) async => sesionValida());
    simularDatos({'invitaciones': [
      {'id':'i-trabajador-frio','correo':correo,'rol':'trabajador','granja_nombre':'Los Pinos',
        'enviada_en':'2026-11-01T12:00:00Z'},
    ]});
    await tester.runAsync(() => Sesion.instance.atenderEnlace(
      Uri.parse('vetlink://confirmar?token_hash=prueba_trabajador_arranque&type=email')));
    await tester.pumpWidget(const FichaMedicaApp());
    await tester.pumpAndSettle();
    expect(find.text('Rol asignado: Trabajador'), findsOneWidget);
  });

  testWidgets('el enlace de confirmación entra directo a la cuenta', (tester) async {
    Sesion.instance.auth = cliente((_) async => sesionValida());
    simularDatos({
      'vinculaciones': [
        {'rol': 'trabajador', 'granjas': filaLosPinos},
      ],
    });
    await tester.pumpWidget(const FichaMedicaApp());
    Sesion.instance.recordarEnlace(Uri.parse('vetlink://confirmar?code=abc'));
    await tester.runAsync(() => Sesion.instance.iniciar(correo, 'clave'));
    await tester.pumpAndSettle();
    expect(find.text('Tu correo quedó confirmado'), findsOneWidget);
    expect(find.byType(CuidadosHoyScreen), findsOneWidget);
  });

  testWidgets('un enlace vencido avisa que hay que pedir otro', (tester) async {
    final auth = cliente((_) async => sesionValida());
    Sesion.instance.auth = auth;
    await tester.pumpWidget(const FichaMedicaApp());
    Sesion.instance.recordarEnlace(Uri.parse('vetlink://confirmar?error=access_denied'));
    // ignore: invalid_use_of_internal_member
    auth.notifyException(AuthException('otp_expired'));
    await tester.pumpAndSettle();
    expect(find.text('El enlace venció o ya se usó. Pedí uno nuevo'), findsOneWidget);
  });

  testWidgets('el enlace con token_hash de confirmación valida el código y entra', (tester) async {
    final pedidos = <http.Request>[];
    Sesion.instance.auth = cliente((pedido) async {
      pedidos.add(pedido);
      return sesionValida();
    });
    simularDatos({
      'vinculaciones': [
        {'rol': 'trabajador', 'granjas': filaLosPinos},
      ],
    });
    await tester.pumpWidget(const FichaMedicaApp());
    await tester.runAsync(() => Sesion.instance.atenderEnlace(Uri.parse('vetlink://confirmar?token_hash=hash_confirmar&type=email')));
    await tester.pumpAndSettle();
    final verificacion = pedidos.singleWhere((p) => p.url.path.endsWith('verify'));
    expect(jsonDecode(verificacion.body), containsPair('token_hash', 'hash_confirmar'));
    expect(jsonDecode(verificacion.body), containsPair('type', 'email'));
    expect(find.text('Tu correo quedó confirmado'), findsOneWidget);
    expect(find.byType(CuidadosHoyScreen), findsOneWidget);

    // 5. El mismo enlace abierto dos veces no gasta el código otra vez.
    await tester.runAsync(() => Sesion.instance.atenderEnlace(Uri.parse('vetlink://confirmar?token_hash=hash_confirmar&type=email')));
    expect(pedidos.where((p) => p.url.path.endsWith('verify')), hasLength(1));
  });

  testWidgets('el enlace con token_hash de recuperación abre Nueva contraseña', (tester) async {
    Sesion.instance.auth = cliente((_) async => sesionValida());
    await tester.pumpWidget(const FichaMedicaApp());
    final suscripcion = Sesion.instance.alRecuperar(
      () => navegador.currentState?.push(MaterialPageRoute(builder: (_) => const NuevaContrasenaScreen())),
    );
    addTearDown(() => suscripcion?.cancel());
    await tester.runAsync(() => Sesion.instance.atenderEnlace(Uri.parse('vetlink://restablecer?token_hash=hash_recuperar&type=recovery')));
    await tester.pumpAndSettle();
    expect(find.byType(NuevaContrasenaScreen), findsOneWidget);
  });

  for (final antesDelOyente in [true,false]) {
    testWidgets('Recuperación con app cerrada y enlace antes del oyente: $antesDelOyente', (tester) async {
      Sesion.instance.auth=cliente((_) async=>sesionValida());
      final uri=Uri.parse('vetlink://restablecer?token_hash=recuperacion_cerrada_$antesDelOyente&type=recovery');
      StreamSubscription<AuthState>? suscripcion;
      if (!antesDelOyente) suscripcion=Sesion.instance.alRecuperar(abrirRecuperacion);
      await tester.runAsync(()=>Sesion.instance.atenderEnlace(uri));
      suscripcion ??= Sesion.instance.alRecuperar(abrirRecuperacion);
      addTearDown(()=>suscripcion?.cancel());
      await tester.pumpWidget(const FichaMedicaApp());
      await tester.pumpAndSettle();
      expect(find.byType(NuevaContrasenaScreen),findsOneWidget);
      // El evento y el resultado de verifyOTP no deben apilar dos pantallas.
      navegador.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.byType(NuevaContrasenaScreen),findsNothing);
      expect(find.text('Bienvenido a VetLink'),findsOneWidget);
    });
  }

  testWidgets('Recuperación desde el login quieto pide un frame y no duplica la pantalla', (tester) async {
    Sesion.instance.auth=cliente((_) async=>sesionValida());
    final suscripcion=Sesion.instance.alRecuperar(abrirRecuperacion);
    addTearDown(()=>suscripcion?.cancel());
    await tester.pumpWidget(const FichaMedicaApp());
    await tester.pumpAndSettle();
    final uri=Uri.parse('vetlink://restablecer?token_hash=recuperacion_frame&type=recovery');
    await tester.runAsync(()=>Sesion.instance.atenderEnlace(uri));
    expect(tester.binding.hasScheduledFrame,isTrue);
    await tester.pumpAndSettle();
    await tester.runAsync(()=>Sesion.instance.atenderEnlace(uri));
    navegador.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.byType(NuevaContrasenaScreen),findsNothing);
  });

  testWidgets('el enlace con token_hash vencido avisa que hay que pedir otro', (tester) async {
    Sesion.instance.auth = cliente((_) async => error(403, 'otp_expired'));
    await tester.pumpWidget(const FichaMedicaApp());
    await tester.runAsync(() => Sesion.instance.atenderEnlace(Uri.parse('vetlink://restablecer?token_hash=hash_vencido&type=recovery')));
    await tester.pumpAndSettle();
    expect(find.text('El enlace venció o ya se usó. Pedí uno nuevo'), findsOneWidget);
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
    await tocar(tester, 'Perfil');
    await tester.pumpAndSettle();
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
