import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:ficha_medica_vacas/logic/granjas.dart';
import 'package:ficha_medica_vacas/models/granja.dart';
import 'package:ficha_medica_vacas/models/miembro.dart';

const losPinos = Granja(
  id: 'g1',
  nombre: 'Los Pinos',
  dueno: 'Ana Pérez',
  superficie: 18,
  runsa: 'SC-02418',
  documento: 'Documento del terreno.pdf',
  confirmada: true,
);

const filaLosPinos = {
  'id': 'g1',
  'nombre': 'Los Pinos',
  'hectareas': 18,
  'runsa': 'SC-02418',
  'documentos_terreno': 'terreno.pdf',
  'confirmada': true,
};

const tablasEquipo = <String, Object>{
  'vinculaciones': [
    {
      'rol': 'dueno',
      'cuentas': {'nombre': 'Ana Pérez', 'identificador': 'ana@ejemplo.com'},
    },
    {
      'rol': 'veterinario',
      'cuentas': {'nombre': 'Sofía Rojas', 'identificador': 'sofia@ejemplo.com'},
    },
    {
      'rol': 'trabajador',
      'cuentas': {'nombre': null, 'identificador': 'luis@ejemplo.com'},
    },
  ],
  'invitaciones': [
    {'id': 'i1', 'correo': 'maria@ejemplo.com', 'rol': 'trabajador', 'enviada_en': '2026-11-01T12:00:00Z'},
  ],
};

/// 1. Prepara Supabase simulado: responde [tablas] por nombre y anota los pedidos en [pedidos].
void simularDatos(
  Map<String, Object> tablas, {
  List<http.BaseRequest>? pedidos,
  bool sinRed = false,
  String? errorAlGuardar,
  bool correoFalla = false,
}) {
  Granjas.instance.cliente = SupabaseClient(
    'https://prueba.supabase.co',
    'clave',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
    postgrestOptions: const PostgrestClientOptions(retryEnabled: false),
    httpClient: MockClient((pedido) async {
      if (sinRed) throw http.ClientException('sin red');
      pedidos?.add(pedido);
      if (errorAlGuardar != null && pedido.method != 'GET') {
        return http.Response(jsonEncode({'code': errorAlGuardar, 'message': 'error'}), 409, request: pedido);
      }
      final nombre = pedido.url.pathSegments.last;
      if (nombre == 'enviar-invitacion') {
        return http.Response(correoFalla ? 'error' : 'ok', correoFalla ? 502 : 200, request: pedido);
      }
      if (nombre == 'invitaciones' && pedido.method == 'POST') {
        return http.Response(jsonEncode({'id': 'nueva'}), 201, request: pedido);
      }
      return http.Response.bytes(
        utf8.encode(jsonEncode(tablas[nombre] ?? const [])),
        200,
        request: pedido,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }),
  );
}

/// 2. Deja a la persona trabajando en Los Pinos con el rol indicado.
void entrarALosPinos({RolMiembro rol = RolMiembro.dueno}) => Granjas.instance.seleccionar((granja: losPinos, rol: rol));
