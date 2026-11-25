import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ficha_medica_vacas/logic/clinica.dart';
import 'package:ficha_medica_vacas/models/registro_clinico.dart';

void main() {
  test('La corrección envía la versión vista y avisa si cambió en el servidor', () async {
    Map<String, dynamic>? cuerpo;
    Clinica.instance.usarApi('https://api.prueba', MockClient((pedido) async {
      cuerpo = jsonDecode(pedido.body) as Map<String, dynamic>;
      return http.Response('{"error":"cambió"}', 409);
    }), token: () => 't', autor: () => 'vet-1');
    final registro = RegistroClinico.desdeApi({
      'id': 'a1', 'fichaBovinaId': 'v1', 'cuentaVeterinarioId': 'vet-1',
      'fecha': '2026-11-20T10:00:00Z', 'tipo': 'Control', 'detalle': 'x', 'version': 3,
    }, reproductivo: false);
    final error = await Clinica.instance.corregir(registro, {'detalle': 'y'});
    expect(cuerpo!['version'], 3);
    expect(error, contains('cambió mientras lo corregías'));
  });
}
