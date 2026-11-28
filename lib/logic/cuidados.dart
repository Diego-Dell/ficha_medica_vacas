import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter/material.dart' show DateUtils;

import '../models/animal.dart';
import 'dosis.dart';
import 'granjas.dart';
import 'sincronizacion.dart';

class Indicacion {
  const Indicacion({
    required this.id,
    required this.animalId,
    required this.nombre,
    required this.tipo,
    required this.dosis,
    required this.unidad,
    this.via,
    this.frecuencia,
    this.duracion,
    this.inicio,
    this.retiro,
    this.aplicadas = 0,
    this.total,
  });

  final String id;
  final String animalId;
  final String nombre;
  final String tipo;
  final double? dosis;
  final String? unidad;
  final String? via, frecuencia, duracion, retiro;
  final DateTime? inicio;
  // Contador para el trabajador: aplicaciones registradas y total indicado.
  final int aplicadas;
  final int? total;

  bool get esTratamiento => tipo == 'Tratamiento';
  bool get completa => total != null && aplicadas >= total!;
  String get contador => 'Número de aplicaciones: $aplicadas/${total ?? '—'}';
}

class AplicacionCuidado {
  const AplicacionCuidado({
    required this.id,
    required this.animalId,
    required this.indicacionId,
    required this.fecha,
    required this.dosis,
    required this.unidad,
    this.observacion,
    this.version,
  });

  final String id;
  final String animalId;
  final String indicacionId;
  // RF-07: versión vista para detectar cambios concurrentes al corregir.
  final int? version;
  final DateTime fecha;
  final double dosis;
  final String unidad;
  final String? observacion;

  factory AplicacionCuidado.desdeApi(Map<String, dynamic> dato) =>
      AplicacionCuidado(
        id: dato['id'] as String,
        animalId: dato['fichaBovinaId'] as String,
        indicacionId: (dato['tratamientoId'] ?? dato['prevencionId']) as String,
        fecha: DateTime.parse(dato['fechaHoraReal'] as String),
        dosis: (dato['dosis'] as num).toDouble(),
        unidad: dato['unidad'] as String,
        observacion: dato['observacion'] as String?,
        version: (dato['version'] as num?)?.toInt(),
      );
}

// Observación y cuidado realizado por el trabajador.
class ObservacionCuidado {
  const ObservacionCuidado({
    required this.id,
    required this.animalId,
    required this.fecha,
    required this.observado,
    required this.cuidado,
    this.version,
  });

  final int? version;

  final String id;
  final String animalId;
  final DateTime fecha;
  final String observado;
  final String cuidado;

  factory ObservacionCuidado.desdeApi(Map<String, dynamic> dato) => ObservacionCuidado(
        id: dato['id'] as String,
        animalId: dato['fichaBovinaId'] as String,
        fecha: DateTime.parse(dato['fechaHora'] as String),
        observado: dato['observado'] as String,
        cuidado: dato['cuidadoRealizado'] as String,
        version: (dato['version'] as num?)?.toInt(),
      );
}

class ErrorCuidados implements Exception {
  const ErrorCuidados(this.mensaje);
  final String mensaje;
  @override
  String toString() => mensaje;
}

/// Acceso a los registros del módulo mediante la API ASP.NET Core.
class Cuidados {
  Cuidados({http.Client? cliente, String? api, String? Function()? token})
    : _cliente = cliente ?? http.Client(),
      _api =
          api ??
          const String.fromEnvironment(
            'API_URL',
            defaultValue: 'https://vetlink-api.onrender.com',
          ),
      _token =
          token ??
          (() => Supabase.instance.client.auth.currentSession?.accessToken);

  static final instance = Cuidados();
  final http.Client _cliente;
  final String _api;
  final String? Function() _token;

  Future<dynamic> _pedir(
    String metodo,
    String ruta, {
    Map<String, dynamic>? cuerpo,
    bool crudo = false,
  }) async {
    if (_api.isEmpty) {
      throw const ErrorCuidados(
        'Falta configurar API_URL para conectar los cuidados.',
      );
    }
    final token = _token();
    if (token == null || token.isEmpty) {
      throw const ErrorCuidados('Iniciá sesión para registrar cuidados.');
    }
    final pedido = http.Request(metodo, Uri.parse('$_api/api/$ruta'))
      ..headers['Authorization'] = 'Bearer $token'
      ..headers['Content-Type'] = 'application/json';
    if (cuerpo != null) {
      pedido.body = jsonEncode(cuerpo);
    }
    try {
      final respuesta = await http.Response.fromStream(
        await _cliente.send(pedido).timeout(const Duration(seconds: 60)),
      );
      if (respuesta.statusCode >= 400) {
        if (respuesta.statusCode == 401) {
          throw const ErrorCuidados(
            'Tu sesión venció. Volvé a iniciar sesión.',
          );
        }
        if (respuesta.statusCode == 403) {
          throw const ErrorCuidados(
            'Tu rol no permite registrar este cuidado.',
          );
        }
        final texto = utf8.decode(respuesta.bodyBytes);
        String? detalle;
        try {
          final dato = jsonDecode(texto);
          if (dato is Map<String, dynamic>) {
            detalle = (dato['error'] ?? dato['title']) as String?;
          }
          if (dato is String) {
            detalle = dato;
          }
        } on FormatException {
          /* La respuesta puede ser texto simple. */
        }
        throw ErrorCuidados(
          detalle ?? 'La API respondió ${respuesta.statusCode}.',
        );
      }
      return respuesta.body.isEmpty
          ? null
          : jsonDecode(utf8.decode(respuesta.bodyBytes));
    } on ErrorCuidados {
      rethrow;
    } on Exception catch (error) {
      // 1. RF-07: sin red el fallo sigue tal cual para guardar en el celular o leer la copia local.
      if (crudo && Sincronizacion.sinConexion(error)) rethrow;
      throw const ErrorCuidados(
        'No se pudo conectar con la API. Revisá internet e intentá de nuevo.',
      );
    }
  }

  // 2. Lecturas con copia local para consultar sin conexión lo ya descargado.
  Future<dynamic> _leer(String ruta) async {
    try {
      return await Sincronizacion.instance.leer('cuidados/$ruta', () => _pedir('GET', ruta, crudo: true));
    } on ErrorCuidados {
      rethrow;
    } on Exception {
      throw const ErrorCuidados('Sin conexión y sin datos guardados en el celular para esta consulta.');
    }
  }

  // 3. RF-07: guarda en el celular y envía; sin conexión queda pendiente.
  Future<EstadoRegistro> _registrar(String tipo, String ruta, Animal animal, Map<String, dynamic> cuerpo) async {
    try {
      return await Sincronizacion.instance.guardar(
        tipo: tipo,
        ruta: '/api/$ruta',
        cuerpo: cuerpo,
        granjaId: Granjas.instance.seleccionada?.id ?? '',
        animalId: animal.id,
        descripcion: '$tipo · ${animal.arete}',
        enviar: (datos) => _pedir('POST', ruta, cuerpo: datos, crudo: true),
      );
    } on ErrorCuidados {
      rethrow;
    } on Exception {
      throw const ErrorCuidados('No se pudo conectar con la API. Revisá internet e intentá de nuevo.');
    }
  }

  Future<List<Indicacion>> indicacionesDe(Animal animal) async {
    if (animal.deBaja) {
      return [];
    }
    return indicacionesDeAnimales([animal]);
  }

  Future<List<Indicacion>> indicacionesDeAnimales(List<Animal> animales) async {
    final activos = {
      for (final animal in animales)
        if (!animal.deBaja) animal.id,
    };
    if (activos.isEmpty) {
      return [];
    }
    final resultados = await Future.wait([
      _leer('tratamientos'),
      _leer('prevenciones'),
      _leer('aplicaciones'),
    ]);
    final tratamientos = resultados[0] as List<dynamic>;
    final prevenciones = resultados[1] as List<dynamic>;
    // Aplicaciones vigentes por indicación, para el contador.
    final aplicadas = <String, int>{};
    for (final a in resultados[2] as List<dynamic>) {
      if (a is Map<String, dynamic> && a['anulado'] != true) {
        final id = (a['tratamientoId'] ?? a['prevencionId']) as String?;
        if (id != null) aplicadas[id] = (aplicadas[id] ?? 0) + 1;
      }
    }
    return [
      for (final valor in tratamientos)
        if (valor is Map<String, dynamic> &&
            activos.contains(valor['fichaBovinaId']) &&
            valor['anulado'] != true &&
            valor['fechaFin'] == null &&
            _vigente(valor['inicio']))
          Indicacion(
            id: valor['id'] as String,
            animalId: valor['fichaBovinaId'] as String,
            nombre: valor['medicamento'] as String,
            tipo: 'Tratamiento',
            dosis: (valor['dosis'] as num?)?.toDouble(),
            unidad: valor['unidad'] as String?,
            via: (valor['via'] ?? valor['viaAdministracion']) as String?,
            frecuencia: valor['frecuencia'] as String?,
            duracion: valor['duracion'] as String?,
            inicio: DateTime.tryParse('${valor['inicio']}'),
            retiro: (valor['retiro'] ?? valor['periodoRetiro']) as String?,
            aplicadas: aplicadas[valor['id']] ?? 0,
            total: totalDosis(valor['frecuencia'] as String?, valor['duracion'] as String?),
          ),
      for (final valor in prevenciones)
        if (valor is Map<String, dynamic> &&
            activos.contains(valor['fichaBovinaId']) &&
            valor['estado'] == 'Pendiente' &&
            valor['tipo'] != 'Control')
          Indicacion(
            id: valor['id'] as String,
            animalId: valor['fichaBovinaId'] as String,
            nombre: valor['nombre'] as String,
            tipo: 'Prevención',
            dosis: (valor['dosis'] as num?)?.toDouble(),
            unidad: valor['unidad'] as String?,
            aplicadas: aplicadas[valor['id']] ?? 0,
            total: 1,
          ),
    ];
  }

  Future<List<AplicacionCuidado>> aplicacionesDe(Animal animal) async {
    final datos = await _leer('aplicaciones?fichaBovinaId=${animal.id}') as List<dynamic>;
    return [
      for (final d in datos)
        if (d is Map<String, dynamic> &&
            d['fichaBovinaId'] == animal.id &&
            d['anulado'] != true)
          AplicacionCuidado.desdeApi(d),
    ];
  }

  Future<EstadoRegistro> registrarAplicacion({
    required Animal animal,
    required Indicacion indicacion,
    required String cuentaId,
    required DateTime fecha,
    required double dosis,
    required String unidad,
    String? observacion,
  }) async {
    if (animal.deBaja || animal.id != indicacion.animalId) {
      throw const ErrorCuidados(
        'La indicación debe pertenecer a un animal activo.',
      );
    }
    if (!dosis.isFinite || dosis <= 0) {
      throw const ErrorCuidados('La dosis debe ser positiva.');
    }
    if (unidad.trim().isEmpty) {
      throw const ErrorCuidados('Ingresá la unidad de la dosis.');
    }
    // F2/F3: la dosis es la indicada y no se supera el total.
    if (indicacion.dosis != null && (dosis != indicacion.dosis || unidad.trim() != (indicacion.unidad ?? '').trim())) {
      throw const ErrorCuidados('La dosis debe ser la indicada por el veterinario.');
    }
    if (indicacion.completa) {
      throw ErrorCuidados('Ya se registraron las ${indicacion.total} aplicaciones de esta indicación.');
    }
    if (fecha.isAfter(DateTime.now().add(const Duration(minutes: 5)))) {
      throw const ErrorCuidados(
        'La fecha de aplicación no puede estar en el futuro.',
      );
    }
    if (indicacion.inicio != null && fecha.isBefore(DateUtils.dateOnly(indicacion.inicio!))) {
      throw const ErrorCuidados('La aplicación no puede ser anterior al inicio del tratamiento.');
    }
    return _registrar('Aplicación', 'aplicaciones', animal, {
        'fichaBovinaId': animal.id,
        'cuentaTrabajadorId': cuentaId,
        'tratamientoId': indicacion.esTratamiento ? indicacion.id : null,
        'prevencionId': indicacion.esTratamiento ? null : indicacion.id,
        'fechaHoraReal': fecha.toUtc().toIso8601String(),
        'dosis': dosis,
        'unidad': unidad.trim(),
        'observacion': observacion?.trim(),
      },
    );
  }

  Future<EstadoRegistro> registrarObservacion({
    required Animal animal,
    required String cuentaId,
    required DateTime fecha,
    required String observado,
    required String cuidado,
  }) async {
    if (animal.deBaja) {
      throw const ErrorCuidados(
        'No se puede registrar un cuidado de un animal dado de baja.',
      );
    }
    if (observado.trim().isEmpty || cuidado.trim().isEmpty) {
      throw const ErrorCuidados(
        'Completá lo observado y el cuidado realizado.',
      );
    }
    if (fecha.isAfter(DateTime.now().add(const Duration(minutes: 5)))) {
      throw const ErrorCuidados(
        'La fecha de observación no puede estar en el futuro.',
      );
    }
    return _registrar('Observación', 'observacionescuidados', animal, {
        'fichaBovinaId': animal.id,
        'cuentaTrabajadorId': cuentaId,
        'fechaHora': fecha.toUtc().toIso8601String(),
        'observado': observado.trim(),
        'cuidadoRealizado': cuidado.trim(),
      },
    );
  }

  Future<List<ObservacionCuidado>> observacionesDe(Animal animal) async {
    final datos = await _leer('observacionescuidados?fichaBovinaId=${animal.id}') as List<dynamic>;
    return [
      for (final d in datos)
        if (d is Map<String, dynamic> && d['fichaBovinaId'] == animal.id && d['anulado'] != true)
          ObservacionCuidado.desdeApi(d),
    ];
  }

  // Una corrección conserva el dato anterior y el motivo en la base.
  Future<void> corregirAplicacion({
    required AplicacionCuidado aplicacion,
    required double dosis,
    required String unidad,
    String? observacion,
    required String motivo,
  }) async {
    if (!dosis.isFinite || dosis <= 0) {
      throw const ErrorCuidados('La dosis debe ser positiva.');
    }
    if (unidad.trim().isEmpty) {
      throw const ErrorCuidados('Ingresá la unidad de la dosis.');
    }
    if (motivo.trim().length < 3) {
      throw const ErrorCuidados('Indicá el motivo de la corrección.');
    }
    await _pedir(
      'PUT',
      'aplicaciones/${aplicacion.id}',
      cuerpo: {
        'fechaHoraReal': aplicacion.fecha.toUtc().toIso8601String(),
        'dosis': dosis,
        'unidad': unidad.trim(),
        'observacion': observacion?.trim(),
        'motivo': motivo.trim(),
        if (aplicacion.version != null) 'version': aplicacion.version,
      },
    );
  }

  Future<void> corregirObservacion({
    required ObservacionCuidado observacion,
    required String observado,
    required String cuidado,
    required String motivo,
  }) async {
    if (observado.trim().isEmpty || cuidado.trim().isEmpty) {
      throw const ErrorCuidados('Completá lo observado y el cuidado realizado.');
    }
    if (motivo.trim().length < 3) {
      throw const ErrorCuidados('Indicá el motivo de la corrección.');
    }
    await _pedir(
      'PUT',
      'observacionescuidados/${observacion.id}',
      cuerpo: {
        'fechaHora': observacion.fecha.toUtc().toIso8601String(),
        'observado': observado.trim(),
        'cuidadoRealizado': cuidado.trim(),
        'motivo': motivo.trim(),
        if (observacion.version != null) 'version': observacion.version,
      },
    );
  }

  static bool _vigente(dynamic inicio) =>
      inicio == null ||
      DateTime.tryParse('$inicio') == null ||
      !DateTime.parse('$inicio').isAfter(DateTime.now());
}
