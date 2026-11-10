import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ficha_medica_vacas/logic/api.dart';
import 'package:ficha_medica_vacas/logic/sesion.dart';
import 'package:ficha_medica_vacas/logic/granjas.dart';
import 'package:ficha_medica_vacas/models/granja.dart';
import 'package:ficha_medica_vacas/models/miembro.dart';

const losPinos = Granja(
  id: 'g1',
  nombre: 'Los Pinos',
  dueno: 'Ana Pérez',
  superficie: 18,
  runsa: 'SC-02418',
  documento: 'terreno.pdf',
  confirmada: true,
);

/// Instala un cliente HTTP aislado para que las pantallas no llamen a internet.
void prepararSesionPrueba() {
  Sesion.instance.api = Api(
    url: 'http://prueba.local',
    cliente: MockClient((http.Request _) async => http.Response('{}', 200)),
  );
}

void entrarALosPinos({RolMiembro rol = RolMiembro.dueno}) =>
    Granjas.instance.seleccionar((granja: losPinos, rol: rol));

void simularDatos(Map<String, Object> _) => prepararSesionPrueba();
