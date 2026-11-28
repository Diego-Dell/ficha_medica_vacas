import 'package:flutter_test/flutter_test.dart';
import 'package:ficha_medica_vacas/logic/cuidados.dart';
import 'package:ficha_medica_vacas/logic/dosis.dart';
import 'package:ficha_medica_vacas/models/animal.dart';

void main() {
  const animal = Animal(id: 'v1', arete: 'BO-1042', etapa: Etapa.vaca);
  Indicacion indicacion({int aplicadas = 2}) => Indicacion(
    id: 't1', animalId: 'v1', nombre: 'Cefalexina', tipo: 'Tratamiento',
    dosis: 5, unidad: 'ml', frecuencia: '24 h', duracion: '10 días', aplicadas: aplicadas, total: 10,
  );

  test('Total de dosis desde Cada y Duración', () {
    expect(totalDosis('24 h', '10 días'), 10);
    expect(totalDosis('12 h', '5 días'), 10);
    expect(totalDosis('única', null), 1);
    expect(totalDosis('según evolución', '5 días'), isNull);
    expect(unidadValida('ML'), 'ml');
    expect(unidadValida('litros'), isNull);
  });

  test('El contador muestra aplicaciones registradas sobre el total', () {
    expect(indicacion().contador, 'Número de aplicaciones: 2/10');
    expect(indicacion(aplicadas: 10).completa, isTrue);
  });

  test('La aplicación rechaza otra dosis y un tratamiento ya completo', () async {
    final cuidados = Cuidados(api: 'https://api.prueba', token: () => 't');
    Future<void> aplicar(Indicacion i, double dosis) => cuidados.registrarAplicacion(
      animal: animal, indicacion: i, cuentaId: 'c1', fecha: DateTime.now(), dosis: dosis, unidad: 'ml');
    await expectLater(aplicar(indicacion(), 6), throwsA(isA<ErrorCuidados>().having((e) => e.mensaje, 'mensaje', contains('indicada'))));
    await expectLater(aplicar(indicacion(aplicadas: 10), 5), throwsA(isA<ErrorCuidados>().having((e) => e.mensaje, 'mensaje', contains('10 aplicaciones'))));
  });
}
