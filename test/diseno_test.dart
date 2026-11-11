import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ficha_medica_vacas/screens/acceso_general/login_screen.dart';
import 'package:ficha_medica_vacas/screens/acceso_general/recuperar_screen.dart';
import 'package:ficha_medica_vacas/screens/dueno_granja/registrar_granja_screen.dart';
import 'package:ficha_medica_vacas/screens/dueno_granja/mi_granja_screen.dart';

import 'apoyo.dart';

void main() {
  for (final ancho in [360.0, 390.0]) {
    testWidgets('Logo y títulos alineados en las cuatro pantallas a $ancho px', (tester) async {
      tester.view.physicalSize = Size(ancho, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      entrarALosPinos();
      simularDatos(const {});
      Offset? marca, titulo;
      for (final pantalla in <(Widget, String)>[
        (const LoginScreen(), 'Bienvenido a VetLink'),
        (const RecuperarScreen(), 'Recuperar contraseña'),
        (const RegistrarGranjaScreen(), 'Registrar mi granja'),
        (const MiGranjaScreen(), 'Mi granja'),
      ]) {
        await tester.pumpWidget(MaterialApp(home: pantalla.$1));
        await tester.pumpAndSettle();
        final posicionMarca = tester.getTopLeft(find.text('VetLink'));
        final posicionTitulo = tester.getTopLeft(find.text(pantalla.$2));
        marca ??= posicionMarca;
        titulo ??= posicionTitulo;
        expect(posicionMarca, marca);
        expect(posicionTitulo, titulo);
        expect(tester.takeException(), isNull);
      }
    });
  }
}
