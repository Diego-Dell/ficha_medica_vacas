import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ficha_medica_vacas/logic/sincronizacion.dart';

void main() {
  final sync = Sincronizacion.instance;
  late AlmacenMemoria almacen;
  late List<Map<String, dynamic>> enviados;
  var respuesta = 201;
  var sinRed = false;

  setUp(() {
    almacen = AlmacenMemoria();
    enviados = [];
    respuesta = 201;
    sinRed = false;
    sync.usar(
      almacen: almacen,
      api: 'https://api.prueba',
      token: () => 'token',
      cuenta: () => 'vet-1',
      cliente: MockClient((pedido) async {
        if (sinRed) throw http.ClientException('sin red');
        enviados.add(jsonDecode(pedido.body) as Map<String, dynamic>);
        return http.Response(respuesta == 403 ? '{"error":"Sin permiso en la granja"}' : '{}', respuesta);
      }),
    );
  });

  tearDown(() => sync.usar());

  Future<EstadoRegistro> guardarSinRed({String granja = 'granja-1'}) => sync.guardar(
        tipo: 'Clínica',
        ruta: '/api/atencionesclinicas',
        cuerpo: {'fichaBovinaId': 'vaca-1', 'detalle': 'Fiebre'},
        granjaId: granja,
        animalId: 'vaca-1',
        descripcion: 'Atención clínica · A-01',
        enviar: (_) async => throw const SocketException('sin red'),
      );

  test('Sin conexión queda guardado en el dispositivo con granja, animal y autor', () async {
    expect(await guardarSinRed(), EstadoRegistro.guardadoEnDispositivo);
    final [pendiente] = await almacen.todos();
    expect((pendiente.granjaId, pendiente.animalId, pendiente.autorId), ('granja-1', 'vaca-1', 'vet-1'));
    expect(pendiente.cuerpo['id'], pendiente.id);
    expect(await sync.porEnviar(), 1);
  });

  test('Al reconectar se envía una sola vez aunque se sincronice de nuevo', () async {
    await guardarSinRed();
    await sync.sincronizar();
    await sync.sincronizar();
    expect(enviados, hasLength(1));
    expect((await almacen.todos()).single.estado, EstadoRegistro.sincronizado);
  });

  test('Un fallo de red conserva el pendiente y el reintento usa el mismo id', () async {
    await guardarSinRed();
    final id = (await almacen.todos()).single.id;
    sinRed = true;
    await sync.sincronizar();
    expect((await almacen.todos()).single.estado, EstadoRegistro.pendiente);
    sinRed = false;
    await sync.sincronizar();
    expect(enviados.single['id'], id);
    expect((await almacen.todos()).single.estado, EstadoRegistro.sincronizado);
  });

  test('Un 409 por envío anterior cuenta como sincronizado', () async {
    await guardarSinRed();
    respuesta = 409;
    await sync.sincronizar();
    expect((await almacen.todos()).single.estado, EstadoRegistro.sincronizado);
  });

  test('Sin autorización se conserva con aviso y sin cambiar de granja', () async {
    await guardarSinRed(granja: 'granja-origen');
    respuesta = 403;
    await sync.sincronizar();
    final pendiente = (await almacen.todos()).single;
    expect(pendiente.estado, EstadoRegistro.rechazado);
    expect(pendiente.granjaId, 'granja-origen');
    expect(pendiente.error, 'Sin permiso en la granja');
  });

  test('Solo se envían los pendientes de la cuenta actual', () async {
    await guardarSinRed();
    sync.usar(almacen: almacen, cuenta: () => 'otra-cuenta');
    await sync.sincronizar();
    expect(enviados, isEmpty);
    expect(await sync.registros(), isEmpty);
  });

  test('Con conexión y datos rechazados no queda nada guardado', () async {
    await expectLater(
      sync.guardar(
        tipo: 'Clínica',
        ruta: '/api/atencionesclinicas',
        cuerpo: const {},
        granjaId: 'g',
        animalId: 'a',
        descripcion: 'x',
        enviar: (_) async => throw StateError('rechazado'),
      ),
      throwsStateError,
    );
    expect(await almacen.todos(), isEmpty);
  });

  test('Sin conexión las consultas usan la última copia descargada', () async {
    expect(await sync.leer('fichas/g', () async => [{'id': 'vaca-1'}]), [{'id': 'vaca-1'}]);
    expect(await sync.leer('fichas/g', () async => throw const SocketException('sin red')), [{'id': 'vaca-1'}]);
  });

  test('Los pendientes se recuperan desde la fila guardada (reinicio de la app)', () async {
    await guardarSinRed();
    final fila = (await almacen.todos()).single.aFila();
    final recuperado = Pendiente.desdeFila(fila);
    expect(recuperado.cuerpo, (await almacen.todos()).single.cuerpo);
    expect(recuperado.estado, EstadoRegistro.guardadoEnDispositivo);
  });
}
