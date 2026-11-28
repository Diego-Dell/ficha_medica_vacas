import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:ficha_medica_vacas/logic/fichas.dart';
import 'package:ficha_medica_vacas/logic/administracion.dart';
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
      'cuenta_id': 'dueno1',
      'cuentas': {'nombre': 'Ana Pérez', 'identificador': 'ana@ejemplo.com'},
    },
    {
      'rol': 'veterinario',
      'cuenta_id': 'vet1',
      'cuentas': {'nombre': 'Sofía Rojas', 'identificador': 'sofia@ejemplo.com'},
    },
    {
      'rol': 'trabajador',
      'cuenta_id': 'trabajador1',
      'cuentas': {'nombre': null, 'identificador': 'luis@ejemplo.com'},
    },
  ],
  'invitaciones': [
    {'id': 'i1', 'correo': 'maria@ejemplo.com', 'rol': 'trabajador', 'enviada_en': '2026-11-01T12:00:00Z'},
  ],
};

/// 1. Prepara Supabase simulado: responde [tablas] por nombre, anota los pedidos en [pedidos] y hace fallar la función [rpcQueFalla].
void simularDatos(
  Map<String, Object> tablas, {
  List<http.BaseRequest>? pedidos,
  bool sinRed = false,
  String? errorAlGuardar,
  bool correoFalla = false,
  String? rpcQueFalla,
}) {
  final cliente = SupabaseClient(
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
      if (pedido.url.path.contains('/storage/v1/object/')) return http.Response('{"Key":"archivo"}', 200, request: pedido, headers: {'content-type': 'application/json'});
      final nombre = pedido.url.pathSegments.last;
      if (nombre == rpcQueFalla) {
        return http.Response(jsonEncode({'code': 'P0001', 'message': 'error'}), 400, request: pedido);
      }
      if (nombre == 'dynamic-action') {
        if (!correoFalla) return http.Response('ok', 200, request: pedido);
        return http.Response.bytes(
          utf8.encode(jsonEncode({'error': 'El envío de correos no está configurado'})),
          500,
          request: pedido,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      if (nombre == 'invitaciones' && pedido.method == 'POST') {
        return http.Response(jsonEncode({'id': 'nueva'}), 201, request: pedido);
      }
      if (nombre == 'mis_invitaciones') {
        return http.Response.bytes(utf8.encode(jsonEncode(tablas['invitaciones'] ?? [])), 200,
          request: pedido, headers: {'content-type': 'application/json; charset=utf-8'});
      }
      var datos = tablas[nombre] ?? (nombre == 'es_administrador' ? false : const []);
      // 3. Una consulta .single() recibe la fila con ese id, o la primera.
      final filas = datos;
      if ((pedido.headers['Accept'] ?? '').contains('vnd.pgrst.object') && filas is List && filas.isNotEmpty) {
        final id = pedido.url.queryParameters['id']?.replaceFirst('eq.', '');
        final lista = filas.cast<Map<String, dynamic>>();
        datos = lista.firstWhere((f) => f['id'] == id, orElse: () => lista.first);
      }
      return http.Response.bytes(
        utf8.encode(jsonEncode(datos)),
        200,
        request: pedido,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }),
  );
  Granjas.instance.cliente = cliente;
  Administracion.instance.usarCliente(MockClient((pedido) async {
    pedidos?.add(pedido);
    final granjas = (tablas['granjas'] as List? ?? []).cast<Map>();
    if (sinRed) throw http.ClientException('sin red');
    Object datos = [];
    if (pedido.url.path.endsWith('/resumen')) {
      datos = {'pendientes': granjas.where((g) => g['confirmada'] == false).length,
        'granjasActivas': granjas.where((g) => g['confirmada'] == true).length, 'cuentas': 0};
    } else if (pedido.url.path.endsWith('/granjas')) {
      datos = [for (final g in granjas) if (g['motivo_rechazo'] == null) {
        ...g, 'documentosTerreno': g['documentos_terreno'],
      }];
    }
    return http.Response(jsonEncode(datos), 200, headers: {'content-type': 'application/json'});
  }), token: () => 'sesion-simulada');
  Fichas.instance.cliente = cliente;
}

/// 2. Deja a la persona trabajando en Los Pinos con el rol indicado.
void entrarALosPinos({RolMiembro rol = RolMiembro.dueno}) => Granjas.instance.seleccionar((granja: losPinos, rol: rol));
