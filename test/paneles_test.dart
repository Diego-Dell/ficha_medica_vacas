import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ficha_medica_vacas/main_vista_previa.dart';
import 'package:ficha_medica_vacas/screens/acceso_general/nueva_contrasena_screen.dart';
import 'package:ficha_medica_vacas/screens/administrador/administracion_screen.dart';
import 'package:ficha_medica_vacas/screens/trabajador/cuidados_hoy_screen.dart';
import 'package:ficha_medica_vacas/screens/veterinario/seguimiento_veterinario_screen.dart';

void main() {
  testWidgets('Los tres paneles abren, responden y vuelven sin Supabase', (
    tester,
  ) async {
    await tester.pumpWidget(const VistaPreviaApp());
    for (final opcion in [
      ('Veterinario', 'Clínica'),
      ('Trabajador', 'Ficha'),
      ('Administrador', 'Cuentas y accesos'),
    ]) {
      await tester.tap(find.text(opcion.$1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('${opcion.$2}  ›'));
      await tester.pumpAndSettle();
      expect(
        find.text('Esta sección todavía no está disponible.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Entendido'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Menú de granjas'));
      await tester.pumpAndSettle();
      expect(find.text('Mis granjas'), findsOneWidget);
      await tester.tap(find.text('Cerrar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cerrar sesión'));
      await tester.pumpAndSettle();
      expect(find.text('Vista previa'), findsOneWidget);
    }
  });

  testWidgets('Nueva contraseña valida y nunca anuncia un cambio real', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: NuevaContrasenaScreen()));
    await tester.tap(find.text('Guardar contraseña'));
    await tester.pump();
    expect(find.text('Campo obligatorio'), findsNWidgets(2));
    await tester.enterText(find.byType(TextFormField).first, 'abcdefgh');
    await tester.enterText(find.byType(TextFormField).last, 'distinta');
    await tester.tap(find.text('Guardar contraseña'));
    await tester.pump();
    expect(find.text('Las contraseñas no coinciden'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).last, 'abcdefgh');
    await tester.tap(find.byTooltip('Mostrar contraseña'));
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField).first).obscureText,
      isFalse,
    );
    await tester.tap(find.text('Guardar contraseña'));
    await tester.pump();
    expect(
      find.text(
        'Las contraseñas coinciden. El guardado aún no está conectado.',
      ),
      findsOneWidget,
    );
  });

  for (final ancho in [360.0, 390.0]) {
    testWidgets(
      'Paneles sin desbordamientos y encabezados alineados a $ancho',
      (tester) async {
        tester.view.physicalSize = Size(ancho, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        Offset? logo, titulo;
        for (final pantalla in <(Widget, String)>[
          (
            const SeguimientoVeterinarioScreen(granja: 'Los Pinos'),
            'Mi granja',
          ),
          (const CuidadosHoyScreen(granja: 'Los Pinos'), 'Mi granja'),
          (
            const AdministracionScreen(granja: 'Los Pinos', pendientes: 1),
            'Administración',
          ),
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
