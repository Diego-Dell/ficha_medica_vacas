import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:ficha_medica_vacas/logic/granjas.dart';
import 'package:ficha_medica_vacas/logic/sesion.dart';
import 'package:ficha_medica_vacas/models/granja.dart';
import 'package:ficha_medica_vacas/screens/granja_revision_screen.dart';
import 'package:ficha_medica_vacas/screens/mi_granja_screen.dart';
import 'package:ficha_medica_vacas/screens/miembros_screen.dart';
import 'package:ficha_medica_vacas/screens/registrar_granja_screen.dart';
import 'package:ficha_medica_vacas/screens/registrar_otra_granja_screen.dart';
import 'package:ficha_medica_vacas/widgets/vetlink.dart';

const losPinos = Granja(
  nombre: 'Los Pinos',
  dueno: 'Ana Pérez',
  superficie: 18,
  runsa: 'SC-02418',
  documento: 'Documento del terreno.pdf',
);

Future<void> abrir(WidgetTester tester, Widget pantalla) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: pantalla));
  await tester.pumpAndSettle();
}

/// Con [atajo] toca el enlace "‹ Volver" del encabezado en vez de un botón con ese texto exacto.
Future<void> tocar(WidgetTester tester, String boton, {bool atajo = false}) async {
  final objetivo = atajo ? find.text('‹ $boton').first : find.text(boton);
  await tester.ensureVisible(objetivo);
  await tester.pumpAndSettle();
  await tester.tap(objetivo);
  await tester.pumpAndSettle();
}

GoTrueClient cliente(MockClientHandler respuesta) => GoTrueClient(
      url: 'https://prueba.supabase.co/auth/v1',
      httpClient: MockClient(respuesta),
      autoRefreshToken: false,
      flowType: AuthFlowType.implicit,
    );

void main() {
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

  testWidgets('Mi granja muestra los datos y las opciones', (tester) async {
    await abrir(tester, const MiGranjaScreen());
    expect(find.text('24'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    for (final opcion in ['Ganado e historial', 'Reportes sanitarios', 'Dar de baja un animal']) {
      expect(find.text('$opcion  ›'), findsOneWidget);
    }
    await tocar(tester, 'Ganado e historial  ›');
    expect(find.text('Ganado e historial estará disponible pronto'), findsOneWidget);
    await tester.tap(find.descendant(of: find.byType(BarraVetLink), matching: find.text('Avisos')));
    await tester.pumpAndSettle();
    expect(find.text('Avisos estará disponible pronto'), findsOneWidget);
  });

  testWidgets('Miembros muestra el equipo y la invitación pendiente', (tester) async {
    await abrir(tester, const MiGranjaScreen());
    await tocar(tester, 'Miembros del equipo  ›');
    expect(find.text('Equipo vinculado a Los Pinos.'), findsOneWidget);
    expect(find.text('Sofía Rojas · Veterinario'), findsOneWidget);
    expect(find.text('Invitación pendiente'), findsOneWidget);
    expect(find.textContaining('Enviada el 01/11/2026'), findsOneWidget);
    await tocar(tester, 'Volver', atajo: true);
    expect(find.text('Mi granja'), findsOneWidget);
  });

  testWidgets('Invitar valida el correo y agrega la invitación a Miembros', (tester) async {
    await abrir(tester, const MiembrosScreen());
    await tocar(tester, 'Invitar persona');
    await tester.enterText(find.byType(TextFormField), 'no-es-correo');
    await tocar(tester, 'Enviar invitación');
    expect(find.text('Correo no válido'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), 'Sofia@ejemplo.com');
    await tocar(tester, 'Enviar invitación');
    expect(find.text('Esa persona ya es miembro de la granja'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), 'nueva@ejemplo.com');
    await tocar(tester, 'Enviar invitación');
    expect(find.textContaining('nueva@ejemplo.com · Veterinario'), findsOneWidget);
    expect(find.text('Invitación pendiente'), findsNWidgets(2));
    expect(find.text('Invitación registrada. El envío por correo aún no está disponible'), findsOneWidget);
  });

  testWidgets('Registrar otra granja valida y guarda el registro', (tester) async {
    await abrir(tester, RegistrarOtraGranjaScreen(elegir: () async => 'adjunto.pdf'));
    await tocar(tester, 'Enviar registro');
    expect(find.text('Campo obligatorio'), findsNWidgets(3));

    final campos = find.byType(TextFormField);
    await tester.enterText(campos.at(0), 'Santa Rosa');
    await tester.enterText(campos.at(1), '12');
    await tester.enterText(campos.at(2), 'SC-02419');
    await tocar(tester, 'Elegir archivo');
    await tocar(tester, 'Enviar registro');
    expect(Granjas.instance.enRevision.single.nombre, 'Santa Rosa');
    expect(Granjas.instance.enRevision.single.superficie, 12);
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
