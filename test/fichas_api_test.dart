import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:ficha_medica_vacas/logic/fichas.dart';
import 'package:ficha_medica_vacas/models/animal.dart';
import 'package:ficha_medica_vacas/models/miembro.dart';

import 'apoyo.dart';

const api = 'https://vetlink-api.onrender.com';

// 1. Ficha como la devuelve la API web.
const luceraApi = {
  'id': 'f1',
  'granjaId': 'g1',
  'identificacion': '0842',
  'nombre': 'Lucera',
  'raza': 'Holstein',
  'etapa': 'Vaca',
  'nacimiento': '2023-03-15',
  'nacimientoEstimado': true,
  'fechaBaja': null,
  'motivoBaja': null,
  'version': 1,
};

void main() {
  final pedidos = <http.Request>[];
  var respuesta = http.Response('', 200);

  setUp(() {
    entrarALosPinos();
    simularDatos(const {});
    pedidos.clear();
    Fichas.instance.usarApi(api, MockClient((pedido) async {
      pedidos.add(pedido);
      return respuesta;
    }));
  });
  tearDown(() => Fichas.instance.usarApi('', http.Client()));

  test('Veterinario envía solo etapa al endpoint y no puede enviar ficha completa', () async {
    entrarALosPinos(rol: RolMiembro.veterinario);
    respuesta = http.Response('', 204);
    final animal = Animal.desdeApi(luceraApi);
    expect(await Fichas.instance.actualizarEtapa(animal, Etapa.vaquilla), isNull);
    expect(pedidos.single.method, 'PATCH');
    expect(pedidos.single.url.path, '/api/fichasbovinas/f1/etapa');
    expect(jsonDecode(pedidos.single.body), {'etapa': 'Vaquilla'});
    expect(await Fichas.instance.actualizar(animal), isNotNull);
    expect(pedidos, hasLength(1));
    entrarALosPinos(rol: RolMiembro.trabajador);
    expect(await Fichas.instance.actualizarEtapa(animal, Etapa.vaquilla), isNotNull);
    expect(pedidos, hasLength(1));
  });

  test('Lista las fichas de la granja actual desde la API y oculta las bajas', () async {
    respuesta = http.Response(jsonEncode([luceraApi, {...luceraApi, 'id': 'f2', 'fechaBaja': '2026-11-01', 'motivoBaja': 'Venta'}]), 200);
    final activos = await Fichas.instance.activos();
    expect(pedidos.single.method, 'GET');
    expect(pedidos.single.url.toString(), '$api/api/fichasbovinas?granjaId=g1');
    expect(pedidos.single.headers['Authorization'], startsWith('Bearer '));
    expect(activos.map((a) => a.titulo), ['Lucera · 0842']);
    expect(activos.single.etapa, Etapa.vaca);
    expect((await Fichas.instance.deLaGranja(conBajas: true)), hasLength(2));
  });

  test('Crea, actualiza y da de baja con el formato de la API', () async {
    respuesta = http.Response(jsonEncode(luceraApi), 201);
    final animal = Animal.desdeApi(luceraApi);
    expect(await Fichas.instance.crear(animal), isNull);
    expect(jsonDecode(pedidos.last.body), {
      'identificacion': '0842', 'nombre': 'Lucera', 'raza': 'Holstein', 'etapa': 'Vaca',
      'nacimiento': '2023-03-15', 'nacimientoEstimado': true, 'granjaId': 'g1',
    });

    respuesta = http.Response('', 204);
    expect(await Fichas.instance.actualizar(animal), isNull);
    expect(pedidos.last.method, 'PUT');
    expect(pedidos.last.url.path, '/api/fichasbovinas/f1');

    expect(await Fichas.instance.darDeBaja(animal, DateTime(2026, 11, 20), ' Venta '), isNull);
    expect(pedidos.last.method, 'DELETE');
    expect(pedidos.last.url.queryParameters, {'motivo': 'Venta', 'fecha': '2026-11-20'});
  });

  test('Traduce los rechazos de la API a mensajes claros', () async {
    final animal = Animal.desdeApi(luceraApi);
    for (final (estado, cuerpo, mensaje) in [
      (400, 'La identificación ya existe en esta granja.', 'Ya existe un animal con esa identificación en esta granja'),
      (403, '{"error":"Tu rol no permite esta operación."}', 'Tu rol no permite este cambio'),
      (401, '', 'Tu sesión venció. Volvé a iniciar sesión'),
      (500, '', 'No se pudo guardar la ficha'),
    ]) {
      respuesta = http.Response.bytes(utf8.encode(cuerpo), estado);
      expect(await Fichas.instance.crear(animal), mensaje, reason: '$estado');
    }
  });
}
