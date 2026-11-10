import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  const ApiException(this.mensaje);
  final String mensaje;
}

/// Cliente del servidor propio. El token solo vive durante esta sesión.
class Api {
  Api({required this.url, http.Client? cliente})
    : cliente = cliente ?? http.Client();
  final String url;
  final http.Client cliente;
  String? token;

  Future<dynamic> pedir(
    String ruta, {
    String metodo = 'GET',
    Map<String, dynamic>? datos,
  }) async {
    if (url.isEmpty) throw const ApiException('La app no está configurada');
    final request = http.Request(metodo, Uri.parse('$url$ruta'));
    request.headers['content-type'] = 'application/json';
    if (token != null) request.headers['authorization'] = 'Bearer $token';
    if (datos != null) request.body = jsonEncode(datos);
    final respuesta = await http.Response.fromStream(
      await cliente.send(request).timeout(const Duration(seconds: 30)),
    );
    final texto = utf8.decode(respuesta.bodyBytes);
    dynamic cuerpo;
    try {
      cuerpo = texto.isEmpty ? <String, dynamic>{} : jsonDecode(texto);
    } on FormatException {
      cuerpo = <String, dynamic>{
        'error': texto.isEmpty ? 'Respuesta no válida del servidor' : texto,
      };
    }
    if (respuesta.statusCode >= 400) {
      final mensaje = cuerpo is Map<String, dynamic> ? cuerpo['error'] : null;
      throw ApiException(
        mensaje is String ? mensaje : 'No se pudo completar la solicitud',
      );
    }
    return cuerpo;
  }
}
