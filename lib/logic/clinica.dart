import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/registro_clinico.dart';

// 1. Una sola entrada para Clínica y Reproducción, siguiendo Fichas.
class Clinica {
  Clinica._();
  static final instance = Clinica._();
  SupabaseClient? _cliente;
  http.Client _http = http.Client();
  String _api = const String.fromEnvironment('API_URL');
  String? Function()? _tokenPrueba, _autorPrueba;

  void conectar(SupabaseClient cliente) => _cliente = cliente;

  @visibleForTesting
  void usarApi(String direccion, http.Client cliente, {String? Function()? token, String? Function()? autor}) {
    _api = direccion;
    _http = cliente;
    _tokenPrueba = token;
    _autorPrueba = autor;
  }

  // 2. El autor viene de la sesión, nunca de un campo editable.
  Future<dynamic> _pedir(String metodo, String ruta, [Map<String, dynamic>? datos]) async {
    if (_api.isEmpty) throw const FalloClinica('Falta configurar API_URL en config.json');
    final token = _tokenPrueba?.call() ?? _cliente?.auth.currentSession?.accessToken;
    final autor = _autorPrueba?.call() ?? _cliente?.auth.currentUser?.id;
    if (token == null || token.isEmpty || autor == null) {
      throw const FalloClinica('Tu sesión venció. Volvé a iniciar sesión');
    }
    final pedido = http.Request(metodo, Uri.parse('${_api.replaceFirst(RegExp(r'/+$'), '')}/api$ruta'));
    pedido.headers.addAll({'Authorization': 'Bearer $token', 'Content-Type': 'application/json'});
    if (datos != null) pedido.body = jsonEncode({...datos, 'cuentaVeterinarioId': autor});
    final respuesta = await _http.send(pedido).then(http.Response.fromStream).timeout(const Duration(seconds: 60));
    if (respuesta.statusCode >= 400) {
      final estado = respuesta.statusCode;
      throw FalloClinica(estado == 401 ? 'Tu sesión venció. Volvé a iniciar sesión'
          : estado == 403 ? 'Tu rol no permite esta operación'
          : estado == 400 ? 'La API rechazó los datos. Revisá los campos y que tu cuenta sea veterinaria de esta granja. Si elegiste Evolución, verificá que el backend esté actualizado.'
          : 'No se pudo completar la operación. Consultá los antecedentes antes de volver a guardar');
    }
    return respuesta.body.isEmpty ? null : jsonDecode(utf8.decode(respuesta.bodyBytes));
  }

  // 3. La API actual lista todos los eventos autorizados: filtramos por ficha.
  Future<List<RegistroClinico>> antecedentes(String animalId, {required bool reproductivos}) async {
    try {
      final ruta = reproductivos ? '/eventosreproductivos' : '/fichasbovinas/${Uri.encodeComponent(animalId)}/atenciones';
      final datos = await _pedir('GET', ruta) as List<dynamic>;
      final registros = datos.map((d) => RegistroClinico.desdeApi(d as Map<String, dynamic>, reproductivo: reproductivos))
          .where((r) => r.animalId == animalId).toList();
      registros.sort((a, b) => b.fecha.compareTo(a.fecha));
      return registros;
    } on FalloClinica { rethrow; }
    on Exception { throw const FalloClinica('No se pudieron cargar los antecedentes. Reintentá'); }
  }

  Future<String?> registrar({required bool reproductivo, required Map<String, dynamic> datos}) async {
    try {
      await _pedir('POST', reproductivo ? '/eventosreproductivos' : '/atencionesclinicas', datos);
      return null;
    } on FalloClinica catch (e) { return e.mensaje; }
    on TimeoutException { return 'La respuesta tardó demasiado. Revisá los antecedentes antes de volver a guardar'; }
    on Exception { return 'No se confirmó el guardado. Revisá tu conexión y los antecedentes antes de reintentar'; }
  }
}

class FalloClinica implements Exception {
  const FalloClinica(this.mensaje);
  final String mensaje;
  @override
  String toString() => mensaje;
}
