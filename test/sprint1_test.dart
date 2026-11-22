import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:ficha_medica_vacas/logic/granjas.dart';
import 'package:ficha_medica_vacas/models/granja.dart';
import 'package:ficha_medica_vacas/models/miembro.dart';
import 'package:ficha_medica_vacas/screens/administrador/administracion_screen.dart';
import 'package:ficha_medica_vacas/screens/administrador/confirmar_granja_screen.dart';
import 'package:ficha_medica_vacas/screens/dueno_granja/expulsar_miembro_screen.dart';
import 'package:ficha_medica_vacas/screens/dueno_granja/granja_revision_screen.dart';
import 'package:ficha_medica_vacas/screens/dueno_granja/miembros_screen.dart';

import 'apoyo.dart';

void main() {
  final equipo = (tablasEquipo['vinculaciones'] as List)
      .cast<Map<String, dynamic>>()
      .map(Miembro.fromMap)
      .toList();
  setUp(() {
    entrarALosPinos();
    simularDatos(tablasEquipo);
  });

  Future<void> tocar(WidgetTester tester, String texto) async {
    await tester.ensureVisible(find.text(texto).last);
    await tester.tap(find.text(texto).last);
    await tester.pumpAndSettle();
  }

  test(
    'Expulsión limita la petición a la granja actual y conserva cuentas',
    () async {
      final pedidos = <http.BaseRequest>[];
      simularDatos(tablasEquipo, pedidos: pedidos);
      expect(await Granjas.instance.expulsar(equipo.last), isNull);
      final pedido = pedidos.single as http.Request;
      expect(pedido.url.path, endsWith('/rpc/expulsar_miembro'));
      expect(jsonDecode(pedido.body), {
        'p_granja': 'g1',
        'p_cuenta': 'trabajador1',
      });
      expect(pedido.method, 'POST');
    },
  );

  test(
    'Ni otro rol ni el propio dueño pueden ser expulsados desde la pantalla',
    () async {
      final pedidos = <http.BaseRequest>[];
      simularDatos(tablasEquipo, pedidos: pedidos);
      expect(await Granjas.instance.expulsar(equipo.first), isNotNull);
      entrarALosPinos(rol: RolMiembro.trabajador);
      expect(await Granjas.instance.expulsar(equipo.last), isNotNull);
      expect(pedidos, isEmpty);
    },
  );

  for (final falla in [false, true]) {
    testWidgets(
      'Expulsar miembro: respuesta ${falla ? 'fallida' : 'correcta'}',
      (tester) async {
        simularDatos(
          tablasEquipo,
          rpcQueFalla: falla ? 'expulsar_miembro' : null,
        );
        await tester.pumpWidget(
          MaterialApp(home: ExpulsarMiembroScreen(miembros: equipo)),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byType(DropdownButtonFormField<Miembro>));
        await tester.pumpAndSettle();
        expect(find.text('Ana Pérez · Dueño'), findsNothing);
        await tocar(tester, 'luis@ejemplo.com · Trabajador');
        await tocar(tester, 'Confirmar expulsión');
        expect(
          find.text('Miembro expulsado'),
          falla ? findsNothing : findsOneWidget,
        );
        if (falla) {
          expect(find.textContaining('No se pudo expulsar'), findsOneWidget);
        } else {
          expect(
            find.text('luis@ejemplo.com ya no tiene acceso a Los Pinos.'),
            findsOneWidget,
          );
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Miembros vuelve a consultar el equipo después de una expulsión',
    (tester) async {
      final pedidos = <http.BaseRequest>[];
      simularDatos(tablasEquipo, pedidos: pedidos);
      await tester.pumpWidget(const MaterialApp(home: MiembrosScreen()));
      await tester.pumpAndSettle();
      await tocar(tester, 'Expulsar de la granja');
      await tester.tap(find.byType(DropdownButtonFormField<Miembro>));
      await tester.pumpAndSettle();
      await tocar(tester, 'Sofía Rojas · Veterinario');
      await tocar(tester, 'Confirmar expulsión');
      simularDatos({
        'vinculaciones': <Object>[],
        'invitaciones': <Object>[],
      }, pedidos: pedidos);
      await tocar(tester, 'Volver a miembros');
      expect(find.text('Sofía Rojas · Veterinario'), findsNothing);
      expect(
        pedidos.where((p) => p.url.path.endsWith('vinculaciones')).length,
        2,
      );
    },
  );

  for (final falla in [false, true]) {
    testWidgets(
      'Rechazo exige motivo y ${falla ? 'muestra el error' : 'regresa al panel'}',
      (tester) async {
        final pedidos = <http.BaseRequest>[];
        simularDatos(
          {
            'granjas': [
              {...filaLosPinos, 'confirmada': false},
            ],
          },
          pedidos: pedidos,
          rpcQueFalla: falla ? 'rechazar_granja' : null,
        );
        await tester.pumpWidget(
          const MaterialApp(home: AdministracionScreen()),
        );
        await tester.pumpAndSettle();
        await tocar(tester, 'Confirmar granjas  ›');
        await tocar(tester, 'Los Pinos · Pendiente  ›');
        await tocar(tester, 'Rechazar solicitud');
        await tocar(tester, 'Rechazar');
        expect(find.text('Campo obligatorio'), findsOneWidget);
        await tester.enterText(
          find.byType(TextFormField),
          'Falta documentación legible',
        );
        await tocar(tester, 'Rechazar');
        final pedido = pedidos.singleWhere(
          (p) => p.url.path.endsWith('rechazar_granja'),
        ) as http.Request;
        expect(jsonDecode(pedido.body), {
          'p_granja': 'g1',
          'p_motivo': 'Falta documentación legible',
        });
        expect(
          find.byType(ConfirmarGranjaScreen),
          falla ? findsOneWidget : findsNothing,
        );
        expect(
          find.textContaining(
            falla ? 'No se pudo rechazar' : 'solicitud rechazada',
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'El dueño ve el motivo y el administrador no vuelve a listar rechazos',
    (tester) async {
      final fila = {
        ...filaLosPinos,
        'confirmada': false,
        'motivo_rechazo': 'Documento ilegible',
      };
      final granja = Granja.fromMap(fila, dueno: 'Ana');
      simularDatos({
        'granjas': [fila],
      });
      expect(await Granjas.instance.porConfirmar(), isEmpty);
      await tester.pumpWidget(
        MaterialApp(home: GranjaRevisionScreen(granja: granja)),
      );
      expect(find.text('Solicitud rechazada'), findsOneWidget);
      expect(find.text('Documento ilegible'), findsOneWidget);
      expect(find.text('Pendiente de confirmación'), findsNothing);
    },
  );
}
