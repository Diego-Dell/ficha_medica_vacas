import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ficha_medica_vacas/main_vista_previa.dart';
import 'package:ficha_medica_vacas/screens/administrador/administracion_screen.dart';
import 'package:ficha_medica_vacas/screens/dueno_granja/mi_granja_screen.dart';
import 'package:ficha_medica_vacas/screens/trabajador/cuidados_hoy_screen.dart';
import 'package:ficha_medica_vacas/screens/veterinario/seguimiento_veterinario_screen.dart';

import 'apoyo.dart';

void main() {
  testWidgets('Los paneles de veterinario y trabajador muestran su acceso y cierran sesión', (tester) async {
    await tester.pumpWidget(const VistaPreviaApp());
    for (final opcion in [
      ('Veterinario', 'Acceso como veterinario'),
      ('Trabajador', 'Acceso como trabajador'),
    ]) {
      await tester.tap(find.text(opcion.$1));
      await tester.pumpAndSettle();
      expect(find.text(opcion.$2), findsOneWidget);
      expect(find.textContaining('Tu cuenta está vinculada a Los Pinos'), findsOneWidget);
      expect(find.text('Mis granjas'), findsOneWidget);
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
