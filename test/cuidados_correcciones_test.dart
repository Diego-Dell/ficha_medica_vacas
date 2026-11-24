import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:ficha_medica_vacas/logic/cuidados.dart';
import 'package:ficha_medica_vacas/models/animal.dart';

void main() {
  const animal = Animal(id: 'f1', arete: '0842', etapa: Etapa.vaca);
  final pedidos = <http.Request>[];
  late Cuidados cuidados;

  setUp(() {
    pedidos.clear();
    cuidados = Cuidados(
      api: 'https://api.prueba',
      token: () => 'token',
      cliente: MockClient((pedido) async {
        pedidos.add(pedido);
        if (pedido.method == 'GET') {
          return http.Response.bytes(utf8.encode(jsonEncode([
            {'id': 'o1', 'fichaBovinaId': 'f1', 'fechaHora': '2026-11-20T10:00:00Z', 'observado': 'Cojea',
             'cuidadoRealizado': 'Limpieza de pezuña', 'anulado': false},
            {'id': 'o2', 'fichaBovinaId': 'f1', 'fechaHora': '2026-11-19T10:00:00Z', 'observado': 'Anulada',
             'cuidadoRealizado': 'x', 'anulado': true},
          ])), 200);
        }
        return http.Response('', 204);
      }),
    );
  });

  test('Lista las observaciones del animal sin las anuladas', () async {
    final observaciones = await cuidados.observacionesDe(animal);
    expect(pedidos.single.url.toString(), 'https://api.prueba/api/observacionescuidados?fichaBovinaId=f1');
    expect(observaciones.map((o) => o.observado), ['Cojea']);
  });

  test('Corregir una aplicación exige motivo y lo envía con los datos nuevos', () async {
    final aplicacion = AplicacionCuidado(
      id: 'a1', animalId: 'f1', indicacionId: 't1', fecha: DateTime.utc(2026, 11, 20, 8), dosis: 5, unidad: 'ml');
    expect(
      () => cuidados.corregirAplicacion(aplicacion: aplicacion, dosis: 6, unidad: 'ml', motivo: ' '),
      throwsA(isA<ErrorCuidados>()),
    );
    expect(pedidos, isEmpty);

    await cuidados.corregirAplicacion(aplicacion: aplicacion, dosis: 6, unidad: 'ml', motivo: 'Dosis mal escrita');
    expect(pedidos.single.method, 'PUT');
    expect(pedidos.single.url.path, '/api/aplicaciones/a1');
    expect(jsonDecode(pedidos.single.body), {
      'fechaHoraReal': '2026-11-20T08:00:00.000Z', 'dosis': 6.0, 'unidad': 'ml', 'observacion': null,
      'motivo': 'Dosis mal escrita',
    });
  });

  test('Corregir una observación envía lo observado, el cuidado y el motivo', () async {
    final observacion = ObservacionCuidado(
      id: 'o1', animalId: 'f1', fecha: DateTime.utc(2026, 11, 20, 10), observado: 'Cojea', cuidado: 'Limpieza');
    await cuidados.corregirObservacion(
      observacion: observacion, observado: 'Cojea leve', cuidado: 'Limpieza de pezuña', motivo: 'Faltaba detalle');
    expect(pedidos.single.url.path, '/api/observacionescuidados/o1');
    expect(jsonDecode(pedidos.single.body)['motivo'], 'Faltaba detalle');
    expect(jsonDecode(pedidos.single.body)['cuidadoRealizado'], 'Limpieza de pezuña');
  });
}
