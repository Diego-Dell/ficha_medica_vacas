import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ficha_medica_vacas/logic/clinica.dart';
import 'package:ficha_medica_vacas/logic/consulta_ganado.dart';
import 'package:ficha_medica_vacas/logic/tratamientos.dart';
import 'package:ficha_medica_vacas/models/animal.dart';
import 'package:ficha_medica_vacas/models/miembro.dart';
import 'package:ficha_medica_vacas/models/prevencion.dart';
import 'package:ficha_medica_vacas/models/registro_clinico.dart';

import 'apoyo.dart';

void main() {
  const vaca = Animal(id: 'f1', arete: 'A-42', nombre: 'Luna', etapa: Etapa.vaca);
  const ternera = Animal(id: 'f2', arete: 'T-12', nombre: 'Sol', etapa: Etapa.ternera);
  final baja = Animal(id: 'f3', arete: 'B-1', etapa: Etapa.vaca,
      fechaBaja: DateTime(2026, 11, 20));

  RegistroClinico evento(String id, String animalId, String fecha,
      {String? aptitud, String? prenez, bool anulado = false}) =>
      RegistroClinico.desdeApi({
        'id': id,
        'fichaBovinaId': animalId,
        'cuentaVeterinarioId': 'vet1',
        'fecha': fecha,
        'tipo': 'Valoracion',
        'aptitud': aptitud,
        'prenez': prenez,
        'anulado': anulado,
      }, reproductivo: true);

  Prevencion prevencion(String id, String animalId, String tipo, String estado,
      String fecha) => Prevencion.fromMap({
        'id': id,
        'fichaBovinaId': animalId,
        'cuentaVeterinarioId': 'vet1',
        'tipo': tipo,
        'nombre': 'Indicación $id',
        'fechaProgramada': fecha,
        'estado': estado,
      });

  test('Filtra nombre, identificación, etapa, aptitud y preñez con la misma lista', () {
    final animales = [vaca, ternera, baja];
    final valoraciones = valoracionesPorAnimal(animales, [
      evento('1', 'f1', '2026-11-20T12:00:00Z', aptitud: 'Apta', prenez: 'Vacia'),
      evento('2', 'f1', '2026-11-22T12:00:00Z', prenez: 'Prenada'),
      evento('3', 'f1', '2026-11-24T12:00:00Z', aptitud: 'NoApta', anulado: true),
      evento('4', 'otra-granja', '2026-11-24T12:00:00Z', aptitud: 'NoApta'),
    ]);
    expect(valoraciones['f1']!.estadoAptitud, 'Apta');
    expect(valoraciones['f1']!.estadoPrenez, 'Prenada');
    expect(valoraciones['f1']!.aptitud!.id, '1');
    expect(valoraciones['f1']!.prenez!.id, '2');
    expect(filtrarGanado(animales, valoraciones,
        busqueda: 'luna', etapa: Etapa.vaca,
        aptitud: 'Apta', prenez: 'Prenada'), [vaca]);
    expect(filtrarGanado(animales, valoraciones, busqueda: 't-12'), [ternera]);
    expect(filtrarGanado(animales, valoraciones, aptitud: ''), [ternera, baja]);
    expect(filtrarGanado(animales, valoraciones, prenez: 'NoEvaluada'),
        [ternera, baja]);
  });

  test('Avisos incluyen solo vacunas y controles pendientes de animales activos', () {
    final avisos = avisosDeGranja([vaca, ternera, baja], [
      prevencion('control', 'f1', 'Control', 'Pendiente', '2026-11-24'),
      prevencion('vacuna', 'f2', 'Vacuna', 'Pendiente', '2026-11-25'),
      prevencion('aplicada', 'f1', 'Vacuna', 'Realizada', '2026-11-23'),
      prevencion('baja', 'f3', 'Control', 'Pendiente', '2026-11-23'),
      prevencion('otra', 'otra-granja', 'Control', 'Pendiente', '2026-11-23'),
      prevencion('desparasitacion', 'f1', 'Desparasitacion', 'Pendiente', '2026-11-23'),
    ], hoy: DateTime(2026, 11, 25));
    expect(avisos.map((a) => a.prevencion.id), ['control', 'vacuna']);
    expect(avisos.first.vencido, isTrue);
    expect(avisos.last.vencido, isFalse);
  });

  test('Las consultas API usan el token y no mezclan otras granjas', () async {
    final pedidos = <http.Request>[];
    Clinica.instance.usarApi('https://ejemplo.test', MockClient((p) async {
      pedidos.add(p);
      return http.Response(jsonEncode([
        {
          'id': 'e1', 'fichaBovinaId': 'f1', 'cuentaVeterinarioId': 'vet1',
          'fecha': '2026-11-22T12:00:00Z', 'tipo': 'Valoracion',
          'aptitud': 'Apta', 'prenez': 'Vacia', 'anulado': false,
        },
        {
          'id': 'e2', 'fichaBovinaId': 'otra-granja',
          'cuentaVeterinarioId': 'vet1', 'fecha': '2026-11-22T12:00:00Z',
          'tipo': 'Valoracion', 'anulado': false,
        },
      ]), 200);
    }), token: () => 'token-prueba', autor: () => 'cuenta1');
    Tratamientos.instance.usarApi('https://ejemplo.test', MockClient((p) async {
      pedidos.add(p);
      return http.Response(jsonEncode([
        {
          'id': 'p1', 'fichaBovinaId': 'f1', 'cuentaVeterinarioId': 'vet1',
          'tipo': 'Control', 'nombre': 'Revisión',
          'fechaProgramada': '2026-11-25', 'estado': 'Pendiente',
        },
        {
          'id': 'p2', 'fichaBovinaId': 'otra-granja',
          'cuentaVeterinarioId': 'vet1', 'tipo': 'Control',
          'nombre': 'Ajeno', 'fechaProgramada': '2026-11-25',
          'estado': 'Pendiente',
        },
      ]), 200);
    }), token: () => 'token-prueba');
    try {
      final eventos = await Clinica.instance.valoracionesDeAnimales([vaca]);
      final prevenciones = await Tratamientos.instance.prevencionesDeAnimales([vaca]);
      expect(eventos.map((e) => e.id), ['e1']);
      expect(prevenciones.map((p) => p.id), ['p1']);
      expect(pedidos.map((p) => p.url.path),
          ['/api/eventosreproductivos', '/api/prevenciones']);
      expect(pedidos.every((p) => p.headers['Authorization'] == 'Bearer token-prueba'), isTrue);
    } finally {
      Clinica.instance.usarApi('', http.Client());
      Tratamientos.instance.usarApi('', http.Client());
    }
  });

  test('Completar un control lo quita de avisos al releer la API', () async {
    entrarALosPinos(rol: RolMiembro.veterinario);
    var estado = 'Pendiente';
    final pedidos = <http.Request>[];
    Tratamientos.instance.usarApi('https://ejemplo.test', MockClient((p) async {
      pedidos.add(p);
      if (p.method == 'POST') {
        estado = 'Realizada';
        return http.Response('', 204);
      }
      return http.Response(jsonEncode([{
        'id': 'control1', 'fichaBovinaId': 'f1',
        'cuentaVeterinarioId': 'vet1', 'tipo': 'Control',
        'nombre': 'Control de prueba', 'fechaProgramada': '2026-11-24',
        'estado': estado, 'version': estado == 'Pendiente' ? 1 : 2,
      }]), 200);
    }), token: () => 'token-prueba');
    try {
      final antes = await Tratamientos.instance.prevencionesDeAnimales([vaca]);
      expect(avisosDeGranja([vaca], antes, hoy: DateTime(2026, 11, 25)),
          hasLength(1));
      expect(await Tratamientos.instance.completarControl(
        animal: vaca, prevencion: antes.single,
        fecha: DateTime(2026, 11, 24),
      ), isNull);
      final despues = await Tratamientos.instance.prevencionesDeAnimales([vaca]);
      expect(avisosDeGranja([vaca], despues, hoy: DateTime(2026, 11, 25)),
          isEmpty);
      expect(pedidos[1].url.path,
          '/api/prevenciones/control1/completar-control');
      expect(jsonDecode(pedidos[1].body)['version'], 1);
    } finally {
      Tratamientos.instance.usarApi('', http.Client());
    }
  });
}
