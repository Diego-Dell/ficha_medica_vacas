import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Las operaciones administrativas viajan a Render con la sesión de Supabase.
class Administracion {
  Administracion._();
  static final instance = Administracion._();
  static const _api = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://vetlink-api.onrender.com',
  );
  http.Client? _clientePrueba;
  String? Function()? _tokenPrueba;

  @visibleForTesting
  void usarCliente(http.Client? cliente, {String? Function()? token}) {
    _clientePrueba = cliente;
    _tokenPrueba = token;
  }

  Future<dynamic> _pedir(
    String metodo,
    String ruta, [
    Map<String, dynamic>? datos,
  ]) async {
    final token =
        _tokenPrueba?.call() ??
        (_clientePrueba == null
            ? Supabase.instance.client.auth.currentSession?.accessToken
            : null);
    if (token == null) throw Exception('Volvé a iniciar sesión');
    final base = _api.replaceFirst(RegExp(r'/+$'), '');
    if (!base.startsWith('https://')) {
      throw Exception('API_URL debe ser la dirección HTTPS de Render');
    }
    final pedido =
        http.Request(metodo, Uri.parse('$base/api/administracion/$ruta'))
          ..headers.addAll({
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          });
    if (datos != null) pedido.body = jsonEncode(datos);
    if (ruta.endsWith('/recuperacion')) {
      const clavePublica = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
      if (clavePublica.isNotEmpty) pedido.headers['apikey'] = clavePublica;
    }
    final cliente = _clientePrueba ?? http.Client();
    try {
      final respuesta = await http.Response.fromStream(
        await cliente.send(pedido),
      ).timeout(const Duration(seconds: 75));
      if (respuesta.statusCode >= 400) {
        if (respuesta.statusCode == 401) {
          throw Exception('Volvé a iniciar sesión');
        }
        if (respuesta.statusCode == 403) {
          throw Exception('Tu cuenta no tiene permiso para esta operación');
        }
        String mensaje = 'La API respondió ${respuesta.statusCode}';
        try {
          final contenido = jsonDecode(utf8.decode(respuesta.bodyBytes));
          if (contenido is Map && contenido['error'] is String) {
            mensaje = contenido['error'] as String;
          }
          if (contenido is String) mensaje = contenido;
        } on FormatException {
          /* La API también puede devolver texto. */
        }
        throw Exception(mensaje);
      }
      return respuesta.body.isEmpty
          ? null
          : jsonDecode(utf8.decode(respuesta.bodyBytes));
    } on TimeoutException {
      throw Exception(
        'La respuesta tardó demasiado. Actualizá la lista antes de reintentar el cambio',
      );
    } finally {
      if (_clientePrueba == null) cliente.close();
    }
  }

  Future<Map<String, dynamic>> resumen() async =>
      Map<String, dynamic>.from(await _pedir('GET', 'resumen') as Map);
  Future<List<Map<String, dynamic>>> cuentas({String buscar = ''}) async =>
      (await _pedir(
        'GET',
        'cuentas?buscar=${Uri.encodeQueryComponent(buscar)}',
      ) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  Future<Map<String, dynamic>> cuenta(String id) async =>
      Map<String, dynamic>.from(await _pedir('GET', 'cuentas/$id') as Map);
  Future<void> guardarCuenta(String id, String nombre, bool activa) async {
    await _pedir('PUT', 'cuentas/$id', {
      'nombre': nombre.trim(),
      'activa': activa,
    });
  }

  Future<void> cambiarAcceso(String vinculacionId, bool activa) async {
    await _pedir('PATCH', 'vinculaciones/$vinculacionId', {'activa': activa});
  }

  Future<void> recuperar(String cuentaId) async {
    await _pedir('POST', 'cuentas/$cuentaId/recuperacion');
  }

  Future<List<Map<String, dynamic>>> granjas() async =>
      (await _pedir('GET', 'granjas') as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
  Future<void> confirmar(String granjaId) async {
    await _pedir('POST', 'granjas/$granjaId/confirmar');
  }

  Future<void> rechazar(String granjaId, String motivo) async {
    await _pedir('POST', 'granjas/$granjaId/rechazar', {
      'motivo': motivo.trim(),
    });
  }

  Future<List<Map<String, dynamic>>> miembros(String granjaId) async =>
      (await _pedir('GET', 'granjas/$granjaId/miembros') as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
}
