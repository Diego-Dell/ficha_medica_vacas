import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/animal.dart';
import '../models/miembro.dart';
import 'granjas.dart';

/// 1. Da un único acceso a las fichas del ganado (Singleton) y esconde las consultas de Supabase detrás de métodos simples (Facade).
class Fichas {
  Fichas._();
  static final instance = Fichas._();

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

  /// 3. El dueño y el trabajador gestionan los datos generales; solo el dueño da de baja (RF-02).
  bool get puedeEditar => Granjas.instance.rol != RolMiembro.veterinario;
  bool get puedeDarDeBaja => Granjas.instance.rol == RolMiembro.dueno;

  /// 4. Trae las fichas de la granja actual; sin [conBajas] solo los animales activos.
  Future<List<Animal>> deLaGranja({bool conBajas = false}) async {
    var consulta = _db.from('fichas_bovinas').select().eq('granja_id', Granjas.instance.actual.id);
    if (!conBajas) consulta = consulta.isFilter('fecha_baja', null);
    final filas = await consulta.order('identificacion');
    return filas.map(Animal.fromMap).toList();
  }

  /// 5. Trae los animales activos; es lo que usan las pantallas de los demás módulos para elegir un animal.
  Future<List<Animal>> activos() => deLaGranja();

  /// 5.1. Trae una ficha por su id, con su estado actual.
  Future<Animal> porId(String id) async =>
      Animal.fromMap(await _db.from('fichas_bovinas').select().eq('id', id).single());

  /// 6. Crea la ficha en la granja actual; devuelve null o el mensaje de error.
  Future<String?> crear(Animal animal) => _guardar(() => _db
      .from('fichas_bovinas')
      .insert({...animal.datosGenerales(), 'granja_id': Granjas.instance.actual.id}));

  /// 7. Actualiza los datos generales; el id no cambia, así los registros del animal siguen vinculados.
  Future<String?> actualizar(Animal animal) =>
      _guardar(() => _db.from('fichas_bovinas').update(animal.datosGenerales()).eq('id', animal.id));

  /// 8. Registra la baja con su fecha y motivo; la ficha y su historial se conservan.
  Future<String?> darDeBaja(Animal animal, DateTime fecha, String motivo) => _guardar(() => _db
      .from('fichas_bovinas')
      .update({'fecha_baja': fecha.toIso8601String().substring(0, 10), 'motivo_baja': motivo.trim()})
      .eq('id', animal.id));

  Future<String?> _guardar(Future<void> Function() accion) async {
    try {
      await accion();
      return null;
    } on PostgrestException catch (e) {
      return switch (e.code) {
        '23505' => 'Ya existe un animal con esa identificación en esta granja',
        '42501' => 'Tu rol no permite este cambio',
        _ => 'No se pudo guardar la ficha',
      };
    } on Exception {
      return 'No se pudo conectar. Revisa tu internet';
    }
  }
}
