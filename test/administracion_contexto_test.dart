import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ficha_medica_vacas/logic/administracion.dart';
import 'package:ficha_medica_vacas/logic/granjas.dart';
import 'package:ficha_medica_vacas/logic/sesion.dart';
import 'package:ficha_medica_vacas/models/granja.dart';
import 'package:ficha_medica_vacas/models/miembro.dart';
import 'package:ficha_medica_vacas/screens/administrador/administracion_screen.dart';
import 'package:ficha_medica_vacas/screens/administrador/confirmar_granja_screen.dart';
import 'package:ficha_medica_vacas/screens/administrador/cuenta_administrativa_screen.dart';
import 'package:ficha_medica_vacas/screens/dueno_granja/granja_revision_screen.dart';
import 'package:ficha_medica_vacas/screens/inicio_por_rol.dart';

import 'apoyo.dart';

void main() {
  final pedidos = <http.Request>[];
  var fallar = false;
  var activa = true;
  setUp(() {
    pedidos.clear();
    fallar = false;
    activa = true;
    simularDatos({});
    Administracion.instance.usarCliente(
      MockClient((p) async {
        pedidos.add(p);
        if (fallar) return http.Response('{"error":"Sin acceso"}', 403);
        final ruta = p.url.path;
        Object datos = {};
        if (ruta.endsWith('/resumen')) {
          datos = {'pendientes': 3, 'granjasActivas': 1, 'cuentas': 1};
        } else if (ruta.endsWith('/granjas')) {
          datos = [
            for (final n in [1, 2, 3])
              {
                'id': 'g$n',
                'nombre': 'Pendiente $n',
                'hectareas': 12,
                'runsa': 'SC-$n',
                'documentosTerreno': 'storage/dueno/g$n/t.pdf',
                'confirmada': false,
              },
            {
              'id': 'g4',
              'nombre': 'Confirmada',
              'hectareas': 12,
              'runsa': 'SC-4',
              'documentosTerreno': '',
              'confirmada': true,
            },
          ];
        } else if (ruta.endsWith('/cuentas')) {
          datos = [
            {
              'id': 'c1',
              'nombre': 'Ana',
              'correo': 'ana@ejemplo.test',
              'activa': activa,
            },
          ];
        } else if (ruta.endsWith('/cuentas/c1')) {
          if (p.method == 'PUT') {
            activa = (jsonDecode(p.body) as Map)['activa'] == true;
            return http.Response('', 204);
          }
          datos = {
            'cuenta': {
              'id': 'c1',
              'nombre': 'Ana',
              'correo': 'ana@ejemplo.test',
              'activa': activa,
            },
            'accesos': <Object>[],
          };
        }
        return http.Response(
          jsonEncode(datos),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
      token: () => 'sesion-prueba',
    );
  });
  tearDown(() => Administracion.instance.usarCliente(null));

  testWidgets(
    'Inicio sintetizado: dos solicitudes, tres pestañas y sin acciones duplicadas',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: AdministracionScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Pendiente 1'), findsOneWidget);
      expect(find.text('Pendiente 2'), findsOneWidget);
      expect(find.text('Pendiente 3'), findsNothing);
      expect(find.text('Gestionar cuentas y accesos'), findsNothing);
      expect(find.byType(NavigationDestination), findsNWidgets(3));
      await tester.tap(find.text('Granjas').last);
      await tester.pumpAndSettle();
      expect(find.text('Pendiente 3'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'SC-2');
      await tester.pump();
      expect(find.text('Pendiente 2'), findsOneWidget);
      expect(find.text('Pendiente 1'), findsNothing);
      await tester.tap(find.text('Pendiente 2'));
      await tester.pumpAndSettle();
      expect(find.byType(ConfirmarGranjaScreen), findsOneWidget);
    },
  );

  testWidgets(
    'Cuenta elegida por id: cancelar desactivación no escribe; confirmar persiste',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: AdministracionScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cuentas').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ana'));
      await tester.pumpAndSettle();
      expect(find.byType(CuentaAdministrativaScreen), findsOneWidget);
      await tester.ensureVisible(find.text('Desactivar cuenta'));
      await tester.tap(find.text('Desactivar cuenta'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(pedidos.where((p) => p.method == 'PUT'), isEmpty);
      await tester.tap(find.text('Desactivar cuenta'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();
      expect(
        pedidos.singleWhere((p) => p.method == 'PUT').url.path,
        '/api/administracion/cuentas/c1',
      );
      expect(activa, isFalse);
    },
  );

  testWidgets('Errores de API permiten reintentar', (tester) async {
    fallar = true;
    await tester.pumpWidget(const MaterialApp(home: AdministracionScreen()));
    await tester.pumpAndSettle();
    expect(find.text('No se pudo cargar la administración'), findsOneWidget);
    fallar = false;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('Gestión general del sistema'), findsOneWidget);
  });
  test('El administrador que también es dueño conserva su panel y no filtra el rol a otra sesión', () async {
    String parte(Map<String, Object> datos) =>
        base64Url.encode(utf8.encode(jsonEncode(datos))).replaceAll('=', '');
    final vence =
        DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
        1000;
    final auth = GoTrueClient(
      url: 'https://prueba.supabase.co/auth/v1',
      autoRefreshToken: false,
      httpClient: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'access_token':
                '${parte({'alg': 'HS256'})}.${parte({'sub': 'admin', 'exp': vence})}.firma',
            'token_type': 'bearer',
            'expires_in': 3600,
            'refresh_token': 'renovar',
            'user': {
              'id': 'admin',
              'aud': 'authenticated',
              'email': 'admin@ejemplo.com',
              'created_at': '2026-11-01T00:00:00Z',
              'app_metadata': {},
              'user_metadata': {},
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );
    Sesion.instance.auth = auth;
    await auth.signInWithPassword(
      email: 'admin@ejemplo.com',
      password: 'prueba123',
    );
    simularDatos({'es_administrador': true});
    expect(await Granjas.instance.esAdministrador(), isTrue);
    const granja = Granja(
      id: 'g2',
      nombre: 'Granja 2',
      dueno: 'Administrador',
      superficie: 1,
      runsa: 'TEST',
      documento: 'terreno.pdf',
    );
    final pantalla = InicioPorRol.crear((
      granja: granja,
      rol: RolMiembro.dueno,
    ));
    expect(pantalla, isA<AdministracionScreen>());
    expect((pantalla as AdministracionScreen).granja?.id, 'g2');
    Sesion.instance.auth = GoTrueClient(
      url: 'https://prueba.supabase.co/auth/v1',
      autoRefreshToken: false,
    );
    expect(
      InicioPorRol.crear((granja: granja, rol: RolMiembro.dueno)),
      isA<GranjaRevisionScreen>(),
    );
    auth.dispose();
  });
}
