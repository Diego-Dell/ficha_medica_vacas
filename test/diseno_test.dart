import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ficha_medica_vacas/screens/acceso_general/login_screen.dart';
import 'package:ficha_medica_vacas/screens/acceso_general/recuperar_screen.dart';
import 'package:ficha_medica_vacas/screens/dueno_granja/registrar_granja_screen.dart';

void main() {
  for (final ancho in [360.0, 390.0]) {
    testWidgets('Bienvenida sin desbordes y encabezados internos alineados a $ancho px', (tester) async {
      tester.view.physicalSize = Size(ancho, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      // 1. La bienvenida muestra marca, título y las dos acciones.
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
      await tester.pumpAndSettle();
      expect(find.text('VetLink'), findsOneWidget);
      expect(find.text('Bienvenido a VetLink'), findsOneWidget);
      expect(find.text('Iniciar sesión'), findsOneWidget);
      expect(find.text('Registrar mi granja'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // 2. Las pantallas internas comparten botón de volver y posición del título.
      Offset? volver, titulo;
      for (final pantalla in <(Widget, String)>[
        (const RecuperarScreen(), 'Recuperar contraseña'),
        (const RegistrarGranjaScreen(), 'Registrar mi granja'),
      ]) {
        await tester.pumpWidget(MaterialApp(home: pantalla.$1));
        await tester.pumpAndSettle();
        final posicionVolver = tester.getTopLeft(find.byTooltip('Volver'));
        final posicionTitulo = tester.getTopLeft(find.text(pantalla.$2).first);
        volver ??= posicionVolver;
        titulo ??= posicionTitulo;
        expect(posicionVolver, volver);
        expect(posicionTitulo, titulo);
        expect(tester.takeException(), isNull);
      }
    });
  }
}
