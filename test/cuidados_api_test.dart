import 'dart:convert';

import 'package:ficha_medica_vacas/logic/cuidados.dart';
import 'package:ficha_medica_vacas/models/animal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const animal = Animal(id: 'a1', arete: 'BO-1042', etapa: Etapa.vaca);
  const otro = Animal(id: 'a2', arete: 'BO-1043', etapa: Etapa.vaca);

  test('solo ofrece indicaciones vigentes del animal elegido', () async {
    final api = Cuidados(
      api: 'https://api.test',
      token: () => 'token',
      cliente: MockClient((pedido) async {
        if (pedido.url.path.endsWith('/tratamientos')) {
          return http.Response(
            jsonEncode([
              {
                'id': 't1',
                'fichaBovinaId': 'a1',
                'medicamento': 'Antibiótico',
                'dosis': 2,
                'unidad': 'mL',
                'anulado': false,
              },
              {
                'id': 't2',
                'fichaBovinaId': 'a2',
                'medicamento': 'Otro',
                'dosis': 1,
                'unidad': 'mL',
                'anulado': false,
              },
              {
                'id': 't3',
                'fichaBovinaId': 'a1',
                'medicamento': 'Anulado',
                'dosis': 1,
                'unidad': 'mL',
                'anulado': true,
              },
              {'id': 't4', 'fichaBovinaId': 'a1', 'medicamento': 'Finalizado',
                'dosis': 1, 'unidad': 'mL', 'fechaFin': '2026-11-01'},
              {'id': 't5', 'fichaBovinaId': 'a1', 'medicamento': 'Futuro',
                'dosis': 1, 'unidad': 'mL', 'inicio': '2100-01-01'},
            ]),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response(
          jsonEncode([
            {
              'id': 'p1',
              'fichaBovinaId': 'a1',
              'nombre': 'Vacuna aftosa',
              'estado': 'Pendiente',
            },
            {
              'id': 'p2',
              'fichaBovinaId': 'a1',
              'nombre': 'Realizada',
              'estado': 'Realizada',
            },
            {'id': 'p3', 'fichaBovinaId': 'a1', 'nombre': 'Control', 'tipo': 'Control', 'estado': 'Pendiente'},
          ]),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    final opciones = await api.indicacionesDe(animal);
    expect(opciones.map((i) => i.id), ['t1', 'p1']);
    expect((await api.indicacionesDe(otro)).map((i) => i.id), ['t2']);
  });

  test('rechaza dosis no positiva antes de enviar', () async {
    final api = Cuidados(
      api: 'https://api.test',
      token: () => 'token',
      cliente: MockClient((_) async {
        fail('No debe enviar la aplicación');
      }),
    );
    await expectLater(
      api.registrarAplicacion(
        animal: animal,
        indicacion: const Indicacion(
          id: 't1',
          animalId: 'a1',
          nombre: 'Antibiótico',
          tipo: 'Tratamiento',
          dosis: 2,
          unidad: 'mL',
        ),
        cuentaId: 'c1',
        fecha: DateTime.now(),
        dosis: 0,
        unidad: 'mL',
      ),
      throwsA(isA<ErrorCuidados>()),
    );
  });

  test('envía la aplicación con token y referencia al mismo animal', () async {
    late http.Request enviado;
    final api = Cuidados(
      api: 'https://api.test',
      token: () => 'token',
      cliente: MockClient((pedido) async {
        enviado = pedido;
        return http.Response('{}', 201);
      }),
    );
    await api.registrarAplicacion(
      animal: animal,
      indicacion: const Indicacion(
        id: 'p1',
        animalId: 'a1',
        nombre: 'Vacuna',
        tipo: 'Prevención',
        dosis: null,
        unidad: null,
      ),
      cuentaId: 'c1',
      fecha: DateTime.now(),
      dosis: 2.5,
      unidad: 'mL',
    );
    expect(enviado.url.path, '/api/aplicaciones');
    expect(enviado.headers['Authorization'], 'Bearer token');
    final cuerpo = jsonDecode(enviado.body) as Map<String, dynamic>;
    expect(cuerpo['fichaBovinaId'], 'a1');
    expect(cuerpo['prevencionId'], 'p1');
    expect(cuerpo['tratamientoId'], isNull);
    expect(cuerpo['dosis'], 2.5);
  });
}
