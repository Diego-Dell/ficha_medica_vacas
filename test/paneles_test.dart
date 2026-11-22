import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ficha_medica_vacas/models/miembro.dart';
import 'package:ficha_medica_vacas/screens/administrador/administracion_screen.dart';
import 'package:ficha_medica_vacas/screens/dueno_granja/mi_granja_screen.dart';
import 'package:ficha_medica_vacas/screens/trabajador/cuidados_hoy_screen.dart';
import 'package:ficha_medica_vacas/screens/veterinario/seguimiento_veterinario_screen.dart';

import 'package:ficha_medica_vacas/screens/dueno_granja/registrar_otra_granja_screen.dart';
import 'apoyo.dart';
import 'package:ficha_medica_vacas/widgets/panel_rol.dart';

void main() {
  testWidgets('Dueño, veterinario y trabajador registran otra granja desde Cambiar de granja', (tester) async {
    for (final (rol, panel) in <(RolMiembro, Widget)>[
      (RolMiembro.dueno, const MiGranjaScreen()),
      (RolMiembro.veterinario, const SeguimientoVeterinarioScreen(granja: 'Los Pinos')),
      (RolMiembro.trabajador, const CuidadosHoyScreen(granja: 'Los Pinos')),
    ]) {
      entrarALosPinos(rol: rol);
      simularDatos(tablasEquipo);
      await tester.pumpWidget(MaterialApp(key: UniqueKey(), home: panel));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Cambiar de granja'));
      await tester.pumpAndSettle();
      expect(find.text('Cambiar de granja'), findsOneWidget);
      await tester.tap(find.text('Registrar otra granja'));
      await tester.pumpAndSettle();
      expect(find.byType(RegistrarOtraGranjaScreen), findsOneWidget);
      expect(find.textContaining('Se usará tu cuenta actual:'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('Veterinario y trabajador ven sus accesos, la barra de íconos y cierran sesión desde Perfil', (tester) async {
    for (final (rol, acceso) in [(RolMiembro.veterinario, 'Clínica'), (RolMiembro.trabajador, 'Observación')]) {
      entrarALosPinos(rol: rol);
      var salio = false;
      final panel = rol == RolMiembro.veterinario
          ? SeguimientoVeterinarioScreen(granja: 'Los Pinos', alCerrarSesion: () => salio = true)
          : CuidadosHoyScreen(granja: 'Los Pinos', alCerrarSesion: () => salio = true);
      await tester.pumpWidget(MaterialApp(key: UniqueKey(), home: panel));
      await tester.pumpAndSettle();
      expect(find.text(acceso), findsOneWidget);
      expect(find.text('Los Pinos · ${rol.etiqueta}'), findsOneWidget);
      // 1. Los registros llegan con los demás módulos del Sprint 2: sus accesos aún no abren nada.
      for (final tarjeta in tester.widgetList<Acceso>(find.byType(Acceso))) {
        expect(tarjeta.alPresionar, isNull, reason: tarjeta.titulo);
      }
      // 2. Una sola forma de llegar a cada sección: la barra inferior.
      for (final pestana in ['Inicio', 'Ganado', 'Perfil']) {
        expect(find.descendant(of: find.byType(NavigationBar), matching: find.text(pestana)), findsOneWidget);
      }
      await tester.tap(find.text('Perfil'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cerrar sesión'));
      await tester.pumpAndSettle();
      expect(salio, isTrue);
    }
  });

  for (final ancho in [360.0, 390.0]) {
    testWidgets('Inicios sin desbordamientos y saludo alineado a $ancho', (tester) async {
      tester.view.physicalSize = Size(ancho, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      entrarALosPinos();
      simularDatos(tablasEquipo);
      Offset? saludo;
      for (final pantalla in <Widget>[
        const SeguimientoVeterinarioScreen(granja: 'Los Pinos'),
        const CuidadosHoyScreen(granja: 'Los Pinos'),
        const MiGranjaScreen(),
        const AdministracionScreen(),
      ]) {
        await tester.pumpWidget(MaterialApp(home: pantalla));
        await tester.pumpAndSettle();
        final posicion = tester.getTopLeft(find.textContaining('Hola'));
        saludo ??= posicion;
        expect(posicion, saludo);
        expect(tester.takeException(), isNull);
      }
    });
  }
}
