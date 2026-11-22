import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/animal.dart';
import 'granjas.dart';

// 1. Acceso único a las fichas del ganado (Singleton + Facade).
class Fichas {
  Fichas._();
  static final instance = Fichas._();

  SupabaseClient? _cliente;

  @visibleForTesting
  set cliente(SupabaseClient valor) => _cliente = valor;

  void conectar(SupabaseClient valor) => _cliente = valor;

  SupabaseClient get _db {
    final cliente = _cliente;
    if (cliente == null) throw Exception('La app no está configurada');
    return cliente;
  }

  // 2. Fichas de la granja actual, con o sin las dadas de baja.
  Future<List<Animal>> deLaGranja({bool conBajas = false}) async {
    var consulta = _db.from('fichas_bovinas').select().eq('granja_id', Granjas.instance.actual.id);
    if (!conBajas) consulta = consulta.isFilter('fecha_baja', null);
    final filas = await consulta.order('identificacion');
    return filas.map(Animal.fromMap).toList();
  }

  // 3. Animales activos: los que admiten nuevos registros.
  Future<List<Animal>> activos() => deLaGranja();

  Future<Animal> porId(String id) async =>
      Animal.fromMap(await _db.from('fichas_bovinas').select().eq('id', id).single());

  Future<String?> crear(Animal animal) => _guardar(() => _db
      .from('fichas_bovinas')
      .insert({...animal.datosGenerales(), 'granja_id': Granjas.instance.actual.id}));

  // 4. Se edita por id, así los registros siguen vinculados.
  Future<String?> actualizar(Animal animal) =>
      _guardar(() => _db.from('fichas_bovinas').update(animal.datosGenerales()).eq('id', animal.id));

  Future<String?> darDeBaja(Animal animal, DateTime fecha, String motivo) => _guardar(() => _db
      .from('fichas_bovinas')
      .update({'fecha_baja': fecha.toIso8601String().substring(0, 10), 'motivo_baja': motivo.trim()})
      .eq('id', animal.id));

  // 5. Devuelve null o el mensaje de error.
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
