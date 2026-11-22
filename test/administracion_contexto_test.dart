import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ficha_medica_vacas/logic/granjas.dart';
import 'package:ficha_medica_vacas/logic/sesion.dart';
import 'package:ficha_medica_vacas/models/granja.dart';
import 'package:ficha_medica_vacas/models/miembro.dart';
import 'package:ficha_medica_vacas/screens/administrador/administracion_screen.dart';
import 'package:ficha_medica_vacas/screens/dueno_granja/granja_revision_screen.dart';
import 'package:ficha_medica_vacas/screens/dueno_granja/mi_granja_screen.dart';
import 'package:ficha_medica_vacas/screens/inicio_por_rol.dart';
import 'package:ficha_medica_vacas/widgets/panel_rol.dart';
import 'apoyo.dart';

void main() {
  final filas = [filaLosPinos, {...filaLosPinos,'id':'g2','nombre':'Granja 2','confirmada':false}];
  Future<void> menu(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Opciones'));
    await tester.pumpAndSettle();
  }
  Future<void> tocar(WidgetTester tester,String texto) async {
    await tester.ensureVisible(find.text(texto).last);
    await tester.tap(find.text(texto).last);
    await tester.pumpAndSettle();
  }

  testWidgets('Administrador inicia con dos tarjetas generales y lista todas las granjas sin registrar otra', (tester) async {
    final pedidos=<http.BaseRequest>[];
    simularDatos({'granjas':filas},pedidos:pedidos);
    await tester.pumpWidget(const MaterialApp(home:AdministracionScreen()));
    await tester.pumpAndSettle();
    expect(find.byType(OpcionPanel),findsNWidgets(2));
    expect(find.text('Cuentas y accesos  ›'),findsOneWidget);
    expect(find.text('Confirmar granjas  ›'),findsOneWidget);
    expect(find.text('Ganado e historial  ›'),findsNothing);
    await menu(tester);
    expect(find.text('Cambiar de granja'),findsOneWidget);
    expect(find.text('Los Pinos'),findsOneWidget);
    expect(find.text('Granja 2'),findsOneWidget);
    expect(find.text('Registrar otra granja'),findsNothing);
    expect(pedidos.any((p)=>p.url.path.endsWith('/granjas') && !p.url.queryParameters.containsKey('confirmada')),isTrue);
    expect(pedidos.where((p)=>p.url.path.endsWith('/vinculaciones')),isEmpty);
  });

  for(final nombre in ['Los Pinos','Granja 2']) {
    testWidgets('Seleccionar $nombre conserva administración y permite volver a gestión general', (tester) async {
      simularDatos({'granjas':filas});
      await tester.pumpWidget(const MaterialApp(home:AdministracionScreen()));
      await tester.pumpAndSettle();
      await menu(tester);
      await tocar(tester,nombre);
      expect(find.text('Administración'),findsOneWidget);
      expect(find.text('Administrador'),findsOneWidget);
      expect(find.text('Operaciones en $nombre'),findsOneWidget);
      expect(find.byType(OpcionPanel),findsNWidgets(4));
      expect(find.byType(MiGranjaScreen),findsNothing);
      expect(find.byType(GranjaRevisionScreen),findsNothing);
      await tocar(tester,'Volver a gestión general');
      expect(find.text('Operaciones en $nombre'),findsNothing);
      expect(find.byType(OpcionPanel),findsNWidgets(2));
      await menu(tester);
      await tocar(tester,nombre);
      await menu(tester);
      await tocar(tester,'Gestión general');
      expect(find.byType(OpcionPanel),findsNWidgets(2));
      expect(find.text('Todas las granjas'),findsOneWidget);
    });
  }

  testWidgets('La lista de granjas permite reintentar sin salir del panel', (tester) async {
    simularDatos({},sinRed:true);
    await tester.pumpWidget(const MaterialApp(home:AdministracionScreen()));
    await tester.pumpAndSettle();
    await menu(tester);
    expect(find.text('No se pudo cargar la lista de granjas. Reintentar'),findsOneWidget);
    simularDatos({'granjas':filas});
    await tocar(tester,'No se pudo cargar la lista de granjas. Reintentar');
    expect(find.text('Granja 2'),findsOneWidget);
  });

  test('El administrador que también es dueño conserva su panel y no filtra el rol a otra sesión', () async {
    String parte(Map<String,Object> datos)=>base64Url.encode(utf8.encode(jsonEncode(datos))).replaceAll('=','');
    final vence=DateTime.now().add(const Duration(hours:1)).millisecondsSinceEpoch~/1000;
    final auth=GoTrueClient(url:'https://prueba.supabase.co/auth/v1',autoRefreshToken:false,
      httpClient:MockClient((_) async=>http.Response(jsonEncode({
        'access_token':'${parte({'alg':'HS256'})}.${parte({'sub':'admin','exp':vence})}.firma',
        'token_type':'bearer','expires_in':3600,'refresh_token':'renovar',
        'user':{'id':'admin','aud':'authenticated','email':'admin@ejemplo.com',
          'created_at':'2026-11-01T00:00:00Z','app_metadata':{},'user_metadata':{}},
      }),200,headers:{'content-type':'application/json'})));
    Sesion.instance.auth=auth;
    await auth.signInWithPassword(email:'admin@ejemplo.com',password:'prueba123');
    simularDatos({'es_administrador':true});
    expect(await Granjas.instance.esAdministrador(),isTrue);
    const granja=Granja(id:'g2',nombre:'Granja 2',dueno:'Administrador',superficie:1,runsa:'TEST',documento:'terreno.pdf');
    final pantalla=InicioPorRol.crear((granja:granja,rol:RolMiembro.dueno));
    expect(pantalla,isA<AdministracionScreen>());
    expect((pantalla as AdministracionScreen).granja?.id,'g2');
    Sesion.instance.auth=GoTrueClient(url:'https://prueba.supabase.co/auth/v1',autoRefreshToken:false);
    expect(InicioPorRol.crear((granja:granja,rol:RolMiembro.dueno)),isA<GranjaRevisionScreen>());
    auth.dispose();
  });
}
