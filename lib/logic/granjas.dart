import '../models/granja.dart';
import '../models/miembro.dart';

/// Datos de las granjas (Singleton). Por ahora son de ejemplo y viven en memoria:
/// se pierden al cerrar la app hasta que existan las tablas en Supabase.
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

  /// Agrega una invitación pendiente. Devuelve null si todo salió bien o el mensaje de error.
  String? invitar(String correo, RolMiembro rol) {
    final limpio = correo.trim().toLowerCase();
    if (miembros.any((m) => m.correo == limpio)) return 'Esa persona ya es miembro de la granja';
    if (invitaciones.any((i) => i.correo == limpio)) return 'Esa persona ya tiene una invitación pendiente';
    invitaciones.add(Invitacion(correo: limpio, rol: rol, enviada: DateTime.now()));
    return null;
  }
}
