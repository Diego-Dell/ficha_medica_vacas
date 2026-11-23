import 'dart:convert';
import 'package:flutter/foundation.dart';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/animal.dart';

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
  });

  final String id;
  final String animalId;
  final String nombre;
  final String tipo;
  final double? dosis;
  final String? unidad;
  final String? via, frecuencia, duracion, retiro;
  final DateTime? inicio;

  bool get esTratamiento => tipo == 'Tratamiento';
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
  });

  final String id;
  final String animalId;
  final String indicacionId;
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
  http.Client _cliente;
  String _api;
  String? Function() _token;
  @visibleForTesting
  void usarApi(String api, http.Client cliente, {required String? Function() token}) {
    _api = api; _cliente = cliente; _token = token;
  }
  SupabaseClient? _supabase;
  void conectar(SupabaseClient cliente) => _supabase = cliente;

  Future<dynamic> _pedir(
    String metodo,
    String ruta, {
    Map<String, dynamic>? cuerpo,
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
    // Estas tablas incluyen el retiro y el cierre que aún no expone el DTO de la API.
    if (metodo == 'GET' && _supabase != null && (ruta == 'tratamientos' || ruta == 'prevenciones')) {
      try {
        final filas = await _supabase!.from(ruta).select();
        return [for (final f in filas) {
          ...f, 'fichaBovinaId': f['ficha_id'], 'fechaFin': f['fecha_fin'],
          'fechaProgramada': f['fecha_programada'],
        }];
      } on Exception {
        throw const ErrorCuidados('No se pudieron cargar las indicaciones. Reintentá.');
      }
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
        if (respuesta.statusCode == 404 && ruta == 'observacionescuidados') {
          throw const ErrorCuidados(
            'La API todavía no permite guardar observaciones. El equipo debe agregar esta ruta.',
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
    } on Exception {
      throw const ErrorCuidados(
        'No se pudo conectar con la API. Revisá internet e intentá de nuevo.',
      );
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
      _pedir('GET', 'tratamientos'),
      _pedir('GET', 'prevenciones'),
    ]);
    final tratamientos = resultados[0] as List<dynamic>;
    final prevenciones = resultados[1] as List<dynamic>;
    final hoy = DateTime.now();
    final dia = DateTime(hoy.year, hoy.month, hoy.day);
    return [
      for (final valor in tratamientos)
        if (valor is Map<String, dynamic> &&
            activos.contains(valor['fichaBovinaId']) &&
            valor['anulado'] != true &&
            valor['fechaFin'] == null &&
            (valor['inicio'] == null || !DateTime.parse(valor['inicio'] as String).isAfter(dia)))
          Indicacion(
            id: valor['id'] as String,
            animalId: valor['fichaBovinaId'] as String,
            nombre: valor['medicamento'] as String,
            tipo: 'Tratamiento',
            dosis: (valor['dosis'] as num?)?.toDouble(),
            unidad: valor['unidad'] as String?,
            via: valor['via'] as String?,
            frecuencia: valor['frecuencia'] as String?,
            duracion: valor['duracion'] as String?,
            inicio: valor['inicio'] == null ? null : DateTime.parse(valor['inicio'] as String),
            retiro: valor['retiro'] as String?,
          ),
      for (final valor in prevenciones)
        if (valor is Map<String, dynamic> &&
            activos.contains(valor['fichaBovinaId']) &&
            (valor['estado'] as String?)?.toLowerCase() == 'pendiente' &&
            (valor['tipo'] as String?)?.toLowerCase() != 'control')
          Indicacion(
            id: valor['id'] as String,
            animalId: valor['fichaBovinaId'] as String,
            nombre: valor['nombre'] as String,
            tipo: 'Prevención',
            dosis: null,
            unidad: null,
          ),
    ];
  }

  Future<List<AplicacionCuidado>> aplicacionesDe(Animal animal) async {
    final datos = await _pedir('GET', 'aplicaciones') as List<dynamic>;
    return [
      for (final d in datos)
        if (d is Map<String, dynamic> &&
            d['fichaBovinaId'] == animal.id &&
            d['anulado'] != true)
          AplicacionCuidado.desdeApi(d),
    ];
  }

  Future<void> registrarAplicacion({
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
    if (fecha.isAfter(DateTime.now().add(const Duration(minutes: 5)))) {
      throw const ErrorCuidados(
        'La fecha de aplicación no puede estar en el futuro.',
      );
    }
    await _pedir(
      'POST',
      'aplicaciones',
      cuerpo: {
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

  Future<void> registrarObservacion({
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
    // Pendiente en la API publicada: esta ruta debe implementarse en el backend compartido.
    await _pedir(
      'POST',
      'observacionescuidados',
      cuerpo: {
        'fichaBovinaId': animal.id,
        'cuentaTrabajadorId': cuentaId,
        'fechaHora': fecha.toUtc().toIso8601String(),
        'observado': observado.trim(),
        'cuidadoRealizado': cuidado.trim(),
      },
    );
  }
}
