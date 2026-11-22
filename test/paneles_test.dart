import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ficha_medica_vacas/main_vista_previa.dart';
import 'package:ficha_medica_vacas/screens/administrador/administracion_screen.dart';
import 'package:ficha_medica_vacas/screens/dueno_granja/mi_granja_screen.dart';
import 'package:ficha_medica_vacas/screens/trabajador/cuidados_hoy_screen.dart';
import 'package:ficha_medica_vacas/screens/veterinario/seguimiento_veterinario_screen.dart';

import 'package:ficha_medica_vacas/screens/dueno_granja/registrar_otra_granja_screen.dart';
import 'apoyo.dart';
import 'package:ficha_medica_vacas/widgets/panel_rol.dart';

void main() {
  testWidgets('Dueño, veterinario y trabajador permiten registrar otra granja desde el menú', (tester) async {
    entrarALosPinos();
    simularDatos(tablasEquipo);
    for (final panel in <Widget>[
      const MiGranjaScreen(),
      const SeguimientoVeterinarioScreen(granja: 'Los Pinos'),
      const CuidadosHoyScreen(granja: 'Los Pinos'),
    ]) {
      await tester.pumpWidget(MaterialApp(key: UniqueKey(), home: panel));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Opciones'));
      await tester.pumpAndSettle();
      expect(find.text('Mis granjas'), findsOneWidget);
      await tester.tap(find.text('Registrar otra granja'));
      await tester.pumpAndSettle();
      expect(find.byType(RegistrarOtraGranjaScreen), findsOneWidget);
      expect(find.textContaining('Se usará tu cuenta actual:'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('Los paneles de veterinario y trabajador muestran su acceso y cierran sesión', (tester) async {
    await tester.pumpWidget(const VistaPreviaApp());
    for (final opcion in [
      ('Veterinario', 'Clínica  ›'),
      ('Trabajador', 'Observación  ›'),
    ]) {
      await tester.tap(find.text(opcion.$1));
      await tester.pumpAndSettle();
      expect(find.text(opcion.$2), findsOneWidget);
      expect(find.text('Los Pinos · ${opcion.$1}'), findsOneWidget);
      // 1. Ficha y Consulta ya abren las fichas del ganado (RF-02); el resto llega con los demás módulos del Sprint 2.
      for (final tarjeta in tester.widgetList<OpcionPanel>(find.byType(OpcionPanel))) {
        expect(tarjeta.alPresionar, ['Ficha', 'Consulta'].contains(tarjeta.titulo) ? isNotNull : isNull,
            reason: tarjeta.titulo);
      }
      expect(find.text('Reportes'), opcion.$1 == 'Trabajador' ? findsNothing : findsOneWidget);
      expect(find.byTooltip('Opciones'), findsOneWidget);
      await tester.tap(find.text('Cerrar sesión'));
      await tester.pumpAndSettle();
      expect(find.text('Vista previa'), findsOneWidget);
    }
  });

  for (final ancho in [360.0, 390.0]) {
    testWidgets(
      'Paneles sin desbordamientos y encabezados alineados a $ancho',
      (tester) async {
        tester.view.physicalSize = Size(ancho, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        entrarALosPinos();
        simularDatos(tablasEquipo);
        Offset? logo, titulo;
        for (final pantalla in <(Widget, String)>[
          (
            const SeguimientoVeterinarioScreen(granja: 'Los Pinos'),
            'Mi granja',
          ),
          (const CuidadosHoyScreen(granja: 'Los Pinos'), 'Mi granja'),
          (const MiGranjaScreen(), 'Mi granja'),
          (const AdministracionScreen(), 'Administración'),
        ]) {
          await tester.pumpWidget(MaterialApp(home: pantalla.$1));
          await tester.pumpAndSettle();
          final marca = tester.getTopLeft(find.text('VetLink'));
          final cabecera = tester.getTopLeft(find.text(pantalla.$2));
          logo ??= marca;
          titulo ??= cabecera;
          expect(marca, logo);
          expect(cabecera, titulo);
          expect(tester.takeException(), isNull);
        }
      },
    );
  }
}
