import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/animal.dart';
import '../models/granja.dart';
import '../models/miembro.dart';
import 'sesion.dart';

typedef Vinculo = ({Granja granja, RolMiembro rol});
typedef Resumen = ({int animales, int avisos, int miembros});

/// 1. Da un único acceso a los datos de las granjas en Supabase (Singleton).
class Granjas {
  Granjas._();
  static final instance = Granjas._();

  SupabaseClient? _cliente;

  @visibleForTesting
  set cliente(SupabaseClient valor) => _cliente = valor;

  /// 2. Conecta el acceso a los datos al abrir la app.
  void conectar(SupabaseClient valor) => _cliente = valor;

  SupabaseClient get _db {
    final cliente = _cliente;
    if (cliente == null) throw Exception('La app no está configurada');
    return cliente;
  }

  /// 3. Recuerda la granja con la que trabaja la persona en esta sesión.
  late Granja actual;
  RolMiembro rol = RolMiembro.trabajador;

  void seleccionar(Vinculo vinculo) {
    actual = vinculo.granja;
    rol = vinculo.rol;
  }

  /// 4. Trae las granjas de la cuenta actual con su rol en cada una.
  Future<List<Vinculo>> misVinculos() async {
    final filas = await _db
        .from('vinculaciones')
        .select('rol, granjas(*)')
        .eq('cuenta_id', Sesion.instance.id ?? '')
        .eq('activa', true);
    return [
      for (final fila in filas)
        (
          granja: Granja.fromMap(fila['granjas'] as Map<String, dynamic>, dueno: Sesion.instance.nombre),
          rol: RolMiembro.values.byName(fila['rol'] as String),
        ),
    ];
  }

  /// 5. Cuenta los animales activos, los avisos de los próximos 7 días y los miembros de la granja actual.
  Future<Resumen> resumen() async {
    final limite = DateTime.now().add(const Duration(days: 7)).toIso8601String().substring(0, 10);
    final id = actual.id;
    final resultados = await Future.wait([
      _db.from('fichas_bovinas').select('id').eq('granja_id', id).isFilter('fecha_baja', null),
      _db
          .from('prevenciones')
          .select('id, fichas_bovinas!inner(granja_id, fecha_baja)')
          .eq('fichas_bovinas.granja_id', id)
          .isFilter('fichas_bovinas.fecha_baja', null)
          .eq('estado', 'pendiente')
          .lte('fecha_programada', limite),
      _db.from('vinculaciones').select('id').eq('granja_id', id).eq('activa', true),
      _db.from('invitaciones').select('id').eq('granja_id', id).eq('vigente', true).eq('aceptada', false),
    ]);
    return (
      animales: resultados[0].length,
      avisos: resultados[1].length,
      miembros: resultados[2].length + resultados[3].length,
    );
  }

  final List<Granja> enRevision = [];

  final List<Miembro> miembros = [
    const Miembro(nombre: 'Ana Pérez', correo: 'ana@ejemplo.com', rol: RolMiembro.dueno),
    const Miembro(nombre: 'Sofía Rojas', correo: 'sofia@ejemplo.com', rol: RolMiembro.veterinario),
    const Miembro(nombre: 'Luis Pérez', correo: 'luis@ejemplo.com', rol: RolMiembro.trabajador),
  ];

  final List<Invitacion> invitaciones = [
    Invitacion(nombre: 'María López', correo: 'maria@ejemplo.com', rol: RolMiembro.trabajador, enviada: DateTime(2026, 11, 1)),
  ];

  /// 6. Ofrece el único animal de ejemplo con ficha para darlo de baja.
  Animal? animalParaBaja = const Animal(nombre: 'Lucera', arete: '0842', categoria: 'Vaca', raza: 'Holstein');

  final List<({Animal animal, DateTime fecha, String motivo})> bajas = [];

  /// 7. Registra la baja del animal.
  void darDeBaja(Animal animal, DateTime fecha, String motivo) {
    bajas.add((animal: animal, fecha: fecha, motivo: motivo));
    animalParaBaja = null;
  }

  /// 8. Agrega una invitación pendiente; devuelve null o el mensaje de error.
  String? invitar(String correo, RolMiembro rol) {
    final limpio = correo.trim().toLowerCase();
    if (miembros.any((m) => m.correo == limpio)) return 'Esa persona ya es miembro de la granja';
    if (invitaciones.any((i) => i.correo == limpio)) return 'Esa persona ya tiene una invitación pendiente';
    invitaciones.add(Invitacion(correo: limpio, rol: rol, enviada: DateTime.now()));
    return null;
  }
}
