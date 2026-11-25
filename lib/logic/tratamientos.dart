import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/animal.dart';
import '../models/miembro.dart';
import '../models/prevencion.dart';
import '../models/registro_clinico.dart';
import '../models/tratamiento.dart';
import 'granjas.dart';
import 'sincronizacion.dart';

// Singleton + Facade. Supabase provee la sesión; los datos viajan únicamente
// por la API HTTP, que es quien aplica las reglas en PostgreSQL.
class Tratamientos {
  Tratamientos._();
  static final instance = Tratamientos._();

  String _apiUrl = const String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://vetlink-api.onrender.com',
  );
  http.Client _clienteHttp = http.Client();
  String? Function()? _token;

  void conectar(SupabaseClient cliente) {
    _token = () => cliente.auth.currentSession?.accessToken;
  }

  // Inyección usada por la vista previa local y por las pruebas HTTP.
  void usarApi(String url, http.Client cliente, {String? Function()? token}) {
    _apiUrl = url.replaceFirst(RegExp(r'/$'), '');
    _clienteHttp = cliente;
    _token = token;
  }

  Future<List<Tratamiento>> delAnimal(String animalId) async {
    final respuesta = await _leer('tratamientos/$animalId', () => _pedir(
      'GET',
      '/api/tratamientos',
      consulta: {'fichaBovinaId': animalId},
      crudo: true,
    ));
    return (respuesta as List)
        .cast<Map>()
        .map((fila) => Tratamiento.fromMap(Map<String, dynamic>.from(fila)))
        .toList();
  }

  Future<List<Prevencion>> prevencionesDelAnimal(String animalId) async {
    final respuesta = await _leer('prevenciones/$animalId', () => _pedir(
      'GET',
      '/api/prevenciones',
      consulta: {'fichaBovinaId': animalId},
      crudo: true,
    ));
    return (respuesta as List)
        .cast<Map>()
        .map((fila) => Prevencion.fromMap(Map<String, dynamic>.from(fila)))
        .toList();
  }

  /// Lee una vez la API y conserva solo las prevenciones de la granja activa.
  Future<List<Prevencion>> prevencionesDeAnimales(List<Animal> animales) async {
    if (animales.isEmpty) return [];
    final ids = animales.map((a) => a.id).toSet();
    final respuesta = await _leer('prevenciones', () => _pedir('GET', '/api/prevenciones', crudo: true));
    return (respuesta as List)
        .cast<Map>()
        .map((fila) => Prevencion.fromMap(Map<String, dynamic>.from(fila)))
        .where((p) => ids.contains(p.animalId))
        .toList();
  }

  // RF-07: con red guarda lo descargado; sin red usa la última copia del celular.
  Future<dynamic> _leer(String clave, Future<dynamic> Function() remoto) async {
    try {
      return await Sincronizacion.instance.leer('tratamientos/$clave', remoto);
    } on FalloTratamientos {
      rethrow;
    } catch (_) {
      throw const FalloTratamientos('Sin conexión y sin datos guardados en el celular para esta consulta.');
    }
  }

  String? _permiso(Animal animal) => animal.deBaja
      ? 'La ficha está dada de baja y no admite nuevos registros'
      : !Granjas.instance.sesionAdministradora && Granjas.instance.rol != RolMiembro.veterinario
      ? 'Solo el veterinario puede indicar tratamientos y prevención'
      : null;

  // Si hay una anterior, la API cierra esa versión y crea otra en una única
  // transacción. Nunca se sobrescribe la prescripción original.
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
    if (indicacion.inicio.isBefore(_dia(atencion.fecha))) {
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

    final datos = {
      ...indicacion.toMap(),
      if (anterior == null) ...{
        'fichaBovinaId': animal.id,
        'atencionClinicaId': atencion.id,
      } else ...{
        'version': anterior.version,
        'fechaFinAnterior': fechaApi(fechaFin!),
        'motivoFinAnterior': motivoFin!.trim(),
      },
    };
    try {
      if (anterior == null) {
        // RF-07: una indicación nueva se guarda en el celular y se envía al haber conexión.
        await _guardarLocal('Tratamiento', '/api/tratamientos', animal, datos);
      } else {
        // El reemplazo usa la versión vista; si cambió, la API lo rechaza para revisarlo.
        await _pedir('POST', '/api/tratamientos/${anterior.id}/reemplazar', cuerpo: datos);
      }
      return null;
    } on FalloTratamientos catch (e) {
      return e.mensaje;
    }
  }

  Future<void> _guardarLocal(String tipo, String ruta, Animal animal, Map<String, dynamic> datos) async {
    try {
      await Sincronizacion.instance.guardar(
        tipo: tipo,
        ruta: ruta,
        cuerpo: datos,
        granjaId: Granjas.instance.seleccionada?.id ?? '',
        animalId: animal.id,
        descripcion: '$tipo · ${animal.arete}',
        enviar: (cuerpo) => _pedir('POST', ruta, cuerpo: cuerpo, crudo: true),
      );
    } on FalloTratamientos {
      rethrow;
    } catch (_) {
      throw const FalloTratamientos('No se pudo conectar con la API. Revisá la URL y tu conexión.');
    }
  }

  String? _validarCierre(
    Tratamiento anterior,
    DateTime? fecha,
    String? motivo,
  ) {
    if (fecha == null || (motivo?.trim().isEmpty ?? true)) {
      return 'Ingresá la fecha y el motivo de cierre';
    }
    final hoy = _dia(DateTime.now());
    if (fecha.isBefore(anterior.inicio) || fecha.isAfter(hoy)) {
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
    try {
      await _pedir(
        'POST',
        '/api/tratamientos/${tratamiento.id}/finalizar',
        cuerpo: {
          'version': tratamiento.version,
          'fechaFin': fechaApi(fecha),
          'motivoFin': motivo.trim(),
        },
      );
      return null;
    } on FalloTratamientos catch (e) {
      return e.mensaje;
    }
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
    if (fecha.isBefore(_dia(DateTime.now()))) {
      return 'La fecha programada no puede ser anterior a hoy';
    }
    try {
      await _guardarLocal('Prevención', '/api/prevenciones', animal, {
        'fichaBovinaId': animal.id,
        'tipo': tipo,
        'nombre': nombre.trim(),
        'fechaProgramada': fechaApi(fecha),
      });
      return null;
    } on FalloTratamientos catch (e) {
      return e.mensaje;
    }
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
    try {
      await _pedir(
        'POST',
        '/api/prevenciones/${prevencion.id}/completar-control',
        cuerpo: {
          'version': prevencion.version,
          'fechaRealizacion': fecha.toUtc().toIso8601String(),
        },
      );
      return null;
    } on FalloTratamientos catch (e) {
      return e.mensaje;
    }
  }

  Future<dynamic> _pedir(
    String metodo,
    String ruta, {
    Map<String, String>? consulta,
    Map<String, dynamic>? cuerpo,
    bool crudo = false,
  }) async {
    final token = _token?.call();
    if (token == null || token.isEmpty) {
      throw const FalloTratamientos(
        'Iniciá sesión antes de usar Tratamientos y prevención',
      );
    }
    final url = Uri.parse('$_apiUrl$ruta').replace(queryParameters: consulta);
    final pedido = http.Request(metodo, url)
      ..headers.addAll({
        'authorization': 'Bearer $token',
        'accept': 'application/json',
        if (cuerpo != null) 'content-type': 'application/json',
      });
    if (cuerpo != null) pedido.body = jsonEncode(cuerpo);
    try {
      final respuesta = await http.Response.fromStream(
        await _clienteHttp.send(pedido).timeout(const Duration(seconds: 60)),
      );
      if (respuesta.statusCode < 200 || respuesta.statusCode >= 300) {
        throw FalloTratamientos(_mensajeRespuesta(respuesta));
      }
      if (respuesta.body.trim().isEmpty) return null;
      return jsonDecode(respuesta.body);
    } on FalloTratamientos {
      rethrow;
    } catch (error) {
      // RF-07: sin red el fallo sigue tal cual para guardar en el celular o leer la copia local.
      if (crudo && Sincronizacion.sinConexion(error)) rethrow;
      throw const FalloTratamientos(
        'No se pudo conectar con la API. Revisá la URL y tu conexión.',
      );
    }
  }

  String _mensajeRespuesta(http.Response respuesta) {
    try {
      final datos = jsonDecode(respuesta.body);
      if (datos is Map && datos['error'] is String) {
        return datos['error'] as String;
      }
    } catch (_) {}
    return switch (respuesta.statusCode) {
      401 => 'Tu sesión venció. Volvé a iniciar sesión.',
      403 => 'Tu sesión o rol no permite esta operación.',
      409 => 'La indicación cambió. Actualizá el historial antes de reintentar',
      503 => 'El módulo todavía no está habilitado en la API.',
      _ => 'No se confirmó la operación. Actualizá el historial antes de reintentar',
    };
  }

  DateTime _dia(DateTime fecha) => DateTime(fecha.year, fecha.month, fecha.day);
}

class FalloTratamientos implements Exception {
  const FalloTratamientos(this.mensaje);
  final String mensaje;
  @override
  String toString() => mensaje;
}
