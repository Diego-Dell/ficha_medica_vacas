import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ficha_medica_vacas/logic/clinica.dart';
import 'package:ficha_medica_vacas/models/registro_clinico.dart';

void main() {
  final pedidos = <http.Request>[];
  var respuesta = http.Response('', 201);
  setUp(() {
    pedidos.clear();
    respuesta = http.Response('', 201);
    Clinica.instance.usarApi('https://ejemplo.test/', MockClient((p) async { pedidos.add(p); return respuesta; }),
      token: () => 'token-prueba', autor: () => 'vet1');
  });
  tearDown(() => Clinica.instance.usarApi('', http.Client()));

  test('Envía el tipo sin reinterpretarlo y toma el autor de la sesión', () async {
    expect(await Clinica.instance.registrar(reproductivo: false, datos: {
      'fichaBovinaId': 'f1', 'cuentaVeterinarioId': 'otro', 'fecha': '2026-11-22T04:00:00Z',
      'tipo': 'Evolucion', 'detalle': 'Evolución favorable',
    }), isNull);
    expect(pedidos.single.url.path, '/api/atencionesclinicas');
    expect(pedidos.single.method, 'POST');
    expect(pedidos.single.headers['Authorization'], 'Bearer token-prueba');
    final cuerpo = jsonDecode(pedidos.single.body) as Map;
    expect(cuerpo['cuentaVeterinarioId'], 'vet1');
    expect(cuerpo['tipo'], 'Evolucion');
  });

  test('Sin evaluar es nulo y las fechas previstas son date-only', () async {
    final fecha = fechaApi(DateTime(2026, 12, 3));
    expect(fecha, '2026-12-03');
    expect(await Clinica.instance.registrar(reproductivo: true, datos: {
      'fichaBovinaId': 'f1', 'tipo': 'Valoracion', 'aptitud': null,
      'prenez': 'NoEvaluada', 'proximoControl': fecha, 'partoProbable': null,
      'fecha': '2026-11-22T04:00:00Z', 'detalle': 'Pendiente de valoración',
    }), isNull);
    expect(pedidos.single.url.path, '/api/eventosreproductivos');
    expect((jsonDecode(pedidos.single.body) as Map)['aptitud'], isNull);
  });

  test('Filtra por animal, ordena y conserva eventos anulados', () async {
    Map<String, dynamic> fila(String id, String animal, String fecha, bool anulado) => {
      'id': id, 'fichaBovinaId': animal, 'cuentaVeterinarioId': 'vet1',
      'fecha': fecha, 'tipo': 'Valoracion', 'anulado': anulado, 'aptitud': 'EnObservacion',
    };
    respuesta = http.Response(jsonEncode([
      fila('1', 'f1', '2026-11-01T04:00:00Z', false),
      fila('2', 'f2', '2026-11-22T04:00:00Z', false),
      fila('3', 'f1', '2026-11-21T04:00:00Z', true),
    ]), 200);
    final registros = await Clinica.instance.antecedentes('f1', reproductivos: true);
    expect(registros.map((r) => r.id), ['3', '1']);
    expect(registros.first.anulado, isTrue);
    expect(registros.first.aptitudTexto, 'En observación');
    expect(pedidos.single.url.query, isEmpty);
    await Clinica.instance.antecedentes('f1', reproductivos: false);
    expect(pedidos.last.url.path, '/api/fichasbovinas/f1/atenciones');
  });

  test('No declara éxito cuando la API rechaza el registro', () async {
    for (final codigo in [400, 401, 403, 500]) {
      respuesta = http.Response('Error', codigo);
      expect(await Clinica.instance.registrar(reproductivo: false, datos: {}), isNotNull);
      await expectLater(Clinica.instance.antecedentes('f1', reproductivos: false), throwsA(isA<FalloClinica>()));
    }
  });

  test('Sin sesión no envía solicitudes', () async {
    Clinica.instance.usarApi('https://ejemplo.test', MockClient((p) async { pedidos.add(p); return respuesta; }), token: () => null, autor: () => null);
    expect(await Clinica.instance.registrar(reproductivo: false, datos: {}), contains('sesión'));
    expect(pedidos, isEmpty);
  });
}
