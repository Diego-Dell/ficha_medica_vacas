import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

// 1. RF-07: estados que ve la persona en cada registro sanitario.
enum EstadoRegistro {
  guardadoEnDispositivo('Guardado en el dispositivo'),
  pendiente('Pendiente de envío'),
  sincronizado('Sincronizado'),
  rechazado('Rechazado por el servidor');

  const EstadoRegistro(this.etiqueta);
  final String etiqueta;
}

// 2. Registro guardado en el celular: conserva granja, animal, autor y el cuerpo con su id.
class Pendiente {
  Pendiente({
    required this.id,
    required this.tipo,
    required this.ruta,
    required this.cuerpo,
    required this.granjaId,
    required this.animalId,
    required this.autorId,
    required this.descripcion,
    this.estado = EstadoRegistro.guardadoEnDispositivo,
    this.intentos = 0,
    this.error,
    DateTime? creadoEn,
    this.sincronizadoEn,
  }) : creadoEn = creadoEn ?? DateTime.now();

  final String id, tipo, ruta, granjaId, animalId, autorId, descripcion;
  final Map<String, dynamic> cuerpo;
  EstadoRegistro estado;
  int intentos;
  String? error;
  final DateTime creadoEn;
  DateTime? sincronizadoEn;

  bool get porEnviar => estado == EstadoRegistro.guardadoEnDispositivo || estado == EstadoRegistro.pendiente;

  Map<String, Object?> aFila() => {
        'id': id,
        'tipo': tipo,
        'ruta': ruta,
        'cuerpo': jsonEncode(cuerpo),
        'granja_id': granjaId,
        'animal_id': animalId,
        'autor_id': autorId,
        'descripcion': descripcion,
        'estado': estado.name,
        'intentos': intentos,
        'error': error,
        'creado_en': creadoEn.toIso8601String(),
        'sincronizado_en': sincronizadoEn?.toIso8601String(),
      };

  factory Pendiente.desdeFila(Map<String, Object?> f) => Pendiente(
        id: f['id'] as String,
        tipo: f['tipo'] as String,
        ruta: f['ruta'] as String,
        cuerpo: jsonDecode(f['cuerpo'] as String) as Map<String, dynamic>,
        granjaId: f['granja_id'] as String,
        animalId: f['animal_id'] as String,
        autorId: f['autor_id'] as String,
        descripcion: f['descripcion'] as String,
        estado: EstadoRegistro.values.byName(f['estado'] as String),
        intentos: f['intentos'] as int? ?? 0,
        error: f['error'] as String?,
        creadoEn: DateTime.parse(f['creado_en'] as String),
        sincronizadoEn: f['sincronizado_en'] == null ? null : DateTime.parse(f['sincronizado_en'] as String),
      );
}

// 3. Dónde se guardan pendientes y copias descargadas (SQLite en la app, memoria en las pruebas).
abstract class AlmacenLocal {
  Future<void> guardar(Pendiente pendiente);
  Future<List<Pendiente>> todos();
  Future<void> borrar(String id);
  Future<void> guardarCopia(String clave, String json);
  Future<String?> leerCopia(String clave);
}

class AlmacenSqlite implements AlmacenLocal {
  AlmacenSqlite._(this._db);
  final Database _db;

  static Future<AlmacenSqlite> abrir() async {
    final db = await openDatabase(
      p.join(await getDatabasesPath(), 'vetlink_local.db'),
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''create table pendientes (
          id text primary key, tipo text not null, ruta text not null, cuerpo text not null,
          granja_id text not null, animal_id text not null, autor_id text not null, descripcion text not null,
          estado text not null, intentos integer not null default 0, error text,
          creado_en text not null, sincronizado_en text)''');
        await db.execute('create table copias (clave text primary key, datos text not null, guardado_en text not null)');
      },
    );
    return AlmacenSqlite._(db);
  }

  @override
  Future<void> guardar(Pendiente pendiente) =>
      _db.insert('pendientes', pendiente.aFila(), conflictAlgorithm: ConflictAlgorithm.replace);

  @override
  Future<List<Pendiente>> todos() async =>
      (await _db.query('pendientes', orderBy: 'creado_en')).map(Pendiente.desdeFila).toList();

  @override
  Future<void> borrar(String id) => _db.delete('pendientes', where: 'id = ?', whereArgs: [id]);

  @override
  Future<void> guardarCopia(String clave, String json) => _db.insert(
        'copias',
        {'clave': clave, 'datos': json, 'guardado_en': DateTime.now().toIso8601String()},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  @override
  Future<String?> leerCopia(String clave) async {
    final filas = await _db.query('copias', where: 'clave = ?', whereArgs: [clave]);
    return filas.isEmpty ? null : filas.first['datos'] as String;
  }
}

class AlmacenMemoria implements AlmacenLocal {
  final _pendientes = <String, Pendiente>{};
  final _copias = <String, String>{};

  @override
  Future<void> guardar(Pendiente pendiente) async => _pendientes[pendiente.id] = pendiente;
  @override
  Future<List<Pendiente>> todos() async =>
      _pendientes.values.toList()..sort((a, b) => a.creadoEn.compareTo(b.creadoEn));
  @override
  Future<void> borrar(String id) async => _pendientes.remove(id);
  @override
  Future<void> guardarCopia(String clave, String json) async => _copias[clave] = json;
  @override
  Future<String?> leerCopia(String clave) async => _copias[clave];
}

// 4. RF-07 (Singleton + Facade): guarda primero en el celular y sincroniza con la API al haber conexión.
class Sincronizacion {
  Sincronizacion._();
  static final instance = Sincronizacion._();

  AlmacenLocal? _almacen;
  http.Client _http = http.Client();
  String _api = const String.fromEnvironment('API_URL');
  String? Function() _token = () => null;
  String? Function() _cuenta = () => null;
  StreamSubscription<List<ConnectivityResult>>? _red;
  Timer? _reloj;
  bool _sincronizando = false;

  // 5. Avisa a las pantallas cuando cambia algún pendiente.
  final cambios = ValueNotifier<int>(0);
  DateTime? ultimaSincronizacion;
  EstadoRegistro? ultimoEstado;

  bool get activa => _almacen != null;

  // 6. Al abrir la app: base local, escucha de la red y reintento cada 30 segundos.
  Future<void> iniciar(SupabaseClient cliente) async {
    _token = () => cliente.auth.currentSession?.accessToken;
    _cuenta = () => cliente.auth.currentUser?.id;
    try {
      _almacen ??= await AlmacenSqlite.abrir();
    } on Exception {
      return; // Sin SQLite (por ejemplo, en escritorio) la app sigue funcionando en línea.
    }
    _red ??= Connectivity().onConnectivityChanged.listen((estado) {
      if (!estado.contains(ConnectivityResult.none)) sincronizar();
    });
    _reloj ??= Timer.periodic(const Duration(seconds: 30), (_) => sincronizar());
    unawaited(sincronizar());
  }

  @visibleForTesting
  void usar({AlmacenLocal? almacen, http.Client? cliente, String? api, String? Function()? token, String? Function()? cuenta}) {
    _almacen = almacen;
    if (cliente != null) _http = cliente;
    if (api != null) _api = api;
    if (token != null) _token = token;
    if (cuenta != null) _cuenta = cuenta;
    ultimoEstado = null;
  }

  // 7. Fallos que indican falta de conexión (no un rechazo del servidor).
  static bool sinConexion(Object error) =>
      error is SocketException || error is http.ClientException || error is TimeoutException;

  // 8. Guardar un registro sanitario: queda en el celular y se envía; sin red queda "Guardado en el dispositivo".
  Future<EstadoRegistro> guardar({
    required String tipo,
    required String ruta,
    required Map<String, dynamic> cuerpo,
    required String granjaId,
    required String animalId,
    required String descripcion,
    required Future<void> Function(Map<String, dynamic> cuerpo) enviar,
  }) async {
    final datos = {...cuerpo, 'id': cuerpo['id'] ?? const Uuid().v4()};
    final almacen = _almacen;
    if (almacen == null) {
      await enviar(datos);
      return ultimoEstado = EstadoRegistro.sincronizado;
    }
    final pendiente = Pendiente(
      id: datos['id'] as String,
      tipo: tipo,
      ruta: ruta,
      cuerpo: datos,
      granjaId: granjaId,
      animalId: animalId,
      autorId: _cuenta() ?? '',
      descripcion: descripcion,
    );
    await almacen.guardar(pendiente);
    _avisar();
    try {
      await enviar(datos);
      pendiente
        ..estado = EstadoRegistro.sincronizado
        ..sincronizadoEn = DateTime.now();
      await almacen.guardar(pendiente);
      _avisar();
      return ultimoEstado = EstadoRegistro.sincronizado;
    } catch (error) {
      if (sinConexion(error)) return ultimoEstado = EstadoRegistro.guardadoEnDispositivo;
      // 9. Con conexión y datos rechazados: no se guarda nada; la pantalla muestra el error para corregirlo.
      await almacen.borrar(pendiente.id);
      _avisar();
      rethrow;
    }
  }

  // 10. Reintenta en orden los pendientes de la cuenta actual; un mismo id nunca se duplica en el servidor.
  Future<void> sincronizar() async {
    final almacen = _almacen;
    final cuenta = _cuenta();
    final token = _token();
    if (almacen == null || _sincronizando || cuenta == null || token == null || _api.isEmpty) return;
    _sincronizando = true;
    try {
      for (final pendiente in await almacen.todos()) {
        if (!pendiente.porEnviar || pendiente.autorId != cuenta) continue;
        final http.Response respuesta;
        try {
          final pedido = http.Request('POST', Uri.parse('${_api.replaceFirst(RegExp(r'/+$'), '')}${pendiente.ruta}'))
            ..headers.addAll({'Authorization': 'Bearer $token', 'Content-Type': 'application/json'})
            ..body = jsonEncode(pendiente.cuerpo);
          respuesta = await http.Response.fromStream(await _http.send(pedido).timeout(const Duration(seconds: 60)));
        } catch (error) {
          if (!sinConexion(error)) rethrow;
          pendiente
            ..estado = EstadoRegistro.pendiente
            ..intentos += 1;
          await almacen.guardar(pendiente);
          break; // Sin red: se reintenta al volver la conexión.
        }
        final estado = respuesta.statusCode;
        if (estado == 401) break; // Sesión vencida: se reintenta al volver a iniciar sesión.
        pendiente.intentos += 1;
        if (estado < 300 || estado == 409) {
          // 11. 409: el registro ya estaba en el servidor por un envío anterior.
          pendiente
            ..estado = EstadoRegistro.sincronizado
            ..sincronizadoEn = DateTime.now()
            ..error = null;
        } else if (estado == 400 || estado == 403 || estado == 404) {
          // 12. Sin autorización o datos inválidos: se conserva con aviso y no se reasigna a otra granja.
          pendiente
            ..estado = EstadoRegistro.rechazado
            ..error = _mensaje(respuesta);
        } else {
          pendiente.estado = EstadoRegistro.pendiente;
        }
        await almacen.guardar(pendiente);
      }
      ultimaSincronizacion = DateTime.now();
    } finally {
      _sincronizando = false;
      _avisar();
    }
  }

  // 13. Lista para la pantalla Sincronización (solo los registros de la cuenta actual).
  Future<List<Pendiente>> registros() async {
    final cuenta = _cuenta();
    final todos = await _almacen?.todos() ?? const <Pendiente>[];
    return todos.where((p) => p.autorId == cuenta).toList().reversed.toList();
  }

  Future<int> porEnviar() async => (await registros()).where((p) => p.porEnviar).length;

  // 14. Descartar un rechazado después de revisarlo.
  Future<void> descartar(Pendiente pendiente) async {
    await _almacen?.borrar(pendiente.id);
    _avisar();
  }

  // 15. Lecturas con copia local: con red guarda lo descargado; sin red devuelve la última copia.
  Future<dynamic> leer(String clave, Future<dynamic> Function() remoto) async {
    final almacen = _almacen;
    final llave = '${_cuenta() ?? ''}:$clave';
    try {
      final datos = await remoto();
      if (almacen != null) await almacen.guardarCopia(llave, jsonEncode(datos));
      return datos;
    } catch (error) {
      if (almacen == null || !sinConexion(error)) rethrow;
      final copia = await almacen.leerCopia(llave);
      if (copia == null) rethrow;
      return jsonDecode(copia);
    }
  }

  String _mensaje(http.Response respuesta) {
    try {
      final datos = jsonDecode(utf8.decode(respuesta.bodyBytes));
      if (datos is Map && datos['error'] is String) return datos['error'] as String;
      if (datos is String) return datos;
    } on FormatException {
      final texto = utf8.decode(respuesta.bodyBytes);
      if (texto.isNotEmpty) return texto;
    }
    return respuesta.statusCode == 403
        ? 'Tu cuenta ya no tiene permiso en esa granja. El registro se conserva en el celular.'
        : 'El servidor rechazó el registro (${respuesta.statusCode}).';
  }

  void _avisar() => cambios.value++;
}
