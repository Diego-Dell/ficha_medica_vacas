import '../models/animal.dart';
import '../models/granja.dart';
import '../models/miembro.dart';

/// 1. Guarda en memoria datos de ejemplo de las granjas (Singleton); se pierden al cerrar la app.
class Granjas {
  Granjas._();
  static final instance = Granjas._();

  final Granja actual = const Granja(
    nombre: 'Los Pinos',
    dueno: 'Ana Pérez',
    superficie: 18,
    runsa: 'SC-02418',
    documento: 'Documento del terreno.pdf',
  );

  final List<Granja> enRevision = [];

  int animales = 24;
  int avisos = 3;

  final List<Miembro> miembros = [
    const Miembro(nombre: 'Ana Pérez', correo: 'ana@ejemplo.com', rol: RolMiembro.dueno),
    const Miembro(nombre: 'Sofía Rojas', correo: 'sofia@ejemplo.com', rol: RolMiembro.veterinario),
    const Miembro(nombre: 'Luis Pérez', correo: 'luis@ejemplo.com', rol: RolMiembro.trabajador),
  ];

  final List<Invitacion> invitaciones = [
    Invitacion(nombre: 'María López', correo: 'maria@ejemplo.com', rol: RolMiembro.trabajador, enviada: DateTime(2026, 11, 1)),
  ];

  int get totalMiembros => miembros.length + invitaciones.length;

  /// 2. Ofrece el único animal de ejemplo con ficha para darlo de baja.
  Animal? animalParaBaja = const Animal(nombre: 'Lucera', arete: '0842', categoria: 'Vaca', raza: 'Holstein');

  final List<({Animal animal, DateTime fecha, String motivo})> bajas = [];

  /// 3. Registra la baja y descuenta el animal.
  void darDeBaja(Animal animal, DateTime fecha, String motivo) {
    bajas.add((animal: animal, fecha: fecha, motivo: motivo));
    animales--;
    animalParaBaja = null;
  }

  /// 4. Agrega una invitación pendiente; devuelve null o el mensaje de error.
  String? invitar(String correo, RolMiembro rol) {
    final limpio = correo.trim().toLowerCase();
    if (miembros.any((m) => m.correo == limpio)) return 'Esa persona ya es miembro de la granja';
    if (invitaciones.any((i) => i.correo == limpio)) return 'Esa persona ya tiene una invitación pendiente';
    invitaciones.add(Invitacion(correo: limpio, rol: rol, enviada: DateTime.now()));
    return null;
  }
}
