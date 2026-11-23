import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/animal.dart';
import '../models/miembro.dart';
import '../models/prevencion.dart';
import '../models/registro_clinico.dart';
import '../models/tratamiento.dart';
import 'granjas.dart';

// Singleton + Facade, igual que Fichas y Clínica.
class Tratamientos {
  Tratamientos._();
  static final instance = Tratamientos._();
  SupabaseClient? _cliente;
  void conectar(SupabaseClient cliente) => _cliente = cliente;
  @visibleForTesting
  set cliente(SupabaseClient? valor) => _cliente = valor;

  SupabaseClient get _db =>
      _cliente ??
      (throw const FalloTratamientos(
        'Falta configurar la conexión con Supabase',
      ));

  Future<List<Tratamiento>> delAnimal(String animalId) async {
    try {
      final filas = await _db
          .from('tratamientos')
          .select()
          .eq('ficha_id', animalId)
          .order('inicio', ascending: false);
      return filas.map(Tratamiento.fromMap).toList();
    } on Exception catch (e) {
      throw FalloTratamientos(_mensaje(e));
    }
  }

  Future<List<Prevencion>> prevencionesDelAnimal(String animalId) async {
    try {
      final filas = await _db
          .from('prevenciones')
          .select()
          .eq('ficha_id', animalId)
          .order('fecha_programada');
      return filas.map(Prevencion.fromMap).toList();
    } on Exception catch (e) {
      throw FalloTratamientos(_mensaje(e));
    }
  }

  String? _permiso(Animal animal) => animal.deBaja
      ? 'La ficha está dada de baja y no admite nuevos registros'
      : Granjas.instance.rol != RolMiembro.veterinario
      ? 'Solo el veterinario puede indicar tratamientos y prevención'
      : null;

  // El cierre y la nueva indicación se guardan juntos, sin sobrescribir datos clínicos.
  Future<String?> guardar({
    required Animal animal,
    required RegistroClinico atencion,
    required IndicacionTratamiento indicacion,
    Tratamiento? anterior,
    DateTime? fechaFin,
    String? motivoFin,
  }) async {
    final error = _permiso(animal) ?? indicacion.validar();
    if (error != null) return error;
    if (atencion.reproductivo ||
        atencion.anulado ||
        atencion.animalId != animal.id) {
      return 'Elegí una atención clínica vigente del mismo animal';
    }
    if (indicacion.inicio.isBefore(
      DateTime(atencion.fecha.year, atencion.fecha.month, atencion.fecha.day),
    )) {
      return 'El inicio no puede ser anterior a la atención';
    }
    if (anterior != null) {
      if (!anterior.vigente ||
          anterior.animalId != animal.id ||
          anterior.atencionId != atencion.id) {
        return 'La indicación ya no está vigente o pertenece a otra atención';
      }
      final cierre = _validarCierre(anterior, fechaFin, motivoFin);
      if (cierre != null) return cierre;
      if (indicacion.inicio.isBefore(fechaFin!)) {
        return 'La nueva indicación no puede comenzar antes del cierre anterior';
      }
    }
    return _guardar('guardar_indicacion_tratamiento', {
      'p_ficha': animal.id,
      'p_atencion': atencion.id,
      'p_datos': indicacion.toMap(),
      'p_anterior': anterior?.id,
      'p_version': anterior?.version,
      'p_fecha_fin': fechaFin == null ? null : fechaApi(fechaFin),
      'p_motivo': motivoFin?.trim(),
    });
  }

  String? _validarCierre(
    Tratamiento anterior,
    DateTime? fecha,
    String? motivo,
  ) {
    if (fecha == null || (motivo?.trim().isEmpty ?? true)) {
      return 'Ingresá la fecha y el motivo de cierre';
    }
    final hoy = DateTime.now();
    if (fecha.isBefore(anterior.inicio) ||
        fecha.isAfter(DateTime(hoy.year, hoy.month, hoy.day))) {
      return 'El cierre debe estar entre el inicio y hoy';
    }
    if (motivo!.trim().length > 500) {
      return 'El motivo admite hasta 500 caracteres';
    }
    return null;
  }

  Future<String?> finalizar({
    required Animal animal,
    required Tratamiento tratamiento,
    required DateTime fecha,
    required String motivo,
  }) async {
    final error =
        _permiso(animal) ?? _validarCierre(tratamiento, fecha, motivo);
    if (error != null) return error;
    if (!tratamiento.vigente || tratamiento.animalId != animal.id) {
      return 'La indicación ya no está vigente';
    }
    return _guardar('finalizar_indicacion_tratamiento', {
      'p_tratamiento': tratamiento.id,
      'p_version': tratamiento.version,
      'p_fecha_fin': fechaApi(fecha),
      'p_motivo': motivo.trim(),
    });
  }

  Future<String?> programar({
    required Animal animal,
    required String tipo,
    required String nombre,
    required DateTime fecha,
  }) async {
    final error = _permiso(animal);
    if (error != null) return error;
    if (!tiposPrevencion.containsKey(tipo) ||
        nombre.trim().isEmpty ||
        nombre.trim().length > 200) {
      return 'Elegí el tipo e ingresá un nombre de hasta 200 caracteres';
    }
    final hoy = DateTime.now();
    if (fecha.isBefore(DateTime(hoy.year, hoy.month, hoy.day))) {
      return 'La fecha programada no puede ser anterior a hoy';
    }
    return _guardar('programar_prevencion', {
      'p_ficha': animal.id,
      'p_tipo': tipo,
      'p_nombre': nombre.trim(),
      'p_fecha': fechaApi(fecha),
    });
  }

  Future<String?> completarControl({
    required Animal animal,
    required Prevencion prevencion,
    required DateTime fecha,
  }) async {
    final error = _permiso(animal);
    if (error != null) return error;
    if (prevencion.animalId != animal.id ||
        !prevencion.pendiente ||
        !prevencion.esControl) {
      return 'Elegí un control pendiente del mismo animal';
    }
    if (fecha.isAfter(DateTime.now())) {
      return 'La realización no puede estar en el futuro';
    }
    return _guardar('completar_control_preventivo', {
      'p_prevencion': prevencion.id,
      'p_version': prevencion.version,
      'p_fecha': fecha.toUtc().toIso8601String(),
    });
  }

  Future<String?> _guardar(
    String funcion,
    Map<String, dynamic> parametros,
  ) async {
    try {
      await _db.rpc(funcion, params: parametros);
      return null;
    } on Exception catch (e) {
      return _mensaje(e);
    }
  }

  String _mensaje(Object e) {
    if (e is FalloTratamientos) return e.mensaje;
    if (e is PostgrestException) {
      if (e.code == 'PGRST202' || e.code == '42703') {
        return 'El módulo de tratamientos todavía no está habilitado en la base de datos';
      }
      if (e.code == '42501') return 'Tu sesión o rol no permite esta operación';
      if (e.code == 'P0001' || e.code == '40001') return e.message;
      return 'No se pudo guardar. Revisá el historial antes de reintentar';
    }
    return 'No se confirmó la operación. Revisá tu conexión y actualizá el historial antes de reintentar';
  }
}

class FalloTratamientos implements Exception {
  const FalloTratamientos(this.mensaje);
  final String mensaje;
  @override
  String toString() => mensaje;
}
