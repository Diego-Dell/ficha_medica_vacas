import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/animal.dart';
import '../models/miembro.dart';
import 'granjas.dart';

// 1. Acceso único a las fichas del ganado (Singleton + Facade).
//    Con API_URL configurada usa la API web (ASP.NET Core en Render); si no, Supabase directo.
class Fichas {
  Fichas._();
  static final instance = Fichas._();

  SupabaseClient? _cliente;
  http.Client _http = http.Client();
  String _api = const String.fromEnvironment('API_URL');

  @visibleForTesting
  set cliente(SupabaseClient valor) => _cliente = valor;

  // 2. Para las pruebas: dirección y cliente HTTP de la API.
  @visibleForTesting
  void usarApi(String direccion, http.Client cliente) {
    _api = direccion;
    _http = cliente;
  }

  void conectar(SupabaseClient valor) => _cliente = valor;

  bool get _conApi => _api.isNotEmpty;

  SupabaseClient get _db {
    final cliente = _cliente;
    if (cliente == null) throw Exception('La app no está configurada');
    return cliente;
  }

  // 3. Fichas de la granja actual, con o sin las dadas de baja.
  Future<List<Animal>> deLaGranja({bool conBajas = false}) async {
    if (_conApi) {
      final respuesta = await _pedir('GET', '', consulta: {'granjaId': Granjas.instance.actual.id});
      final animales = [for (final fila in jsonDecode(respuesta.body) as List) Animal.desdeApi(fila as Map<String, dynamic>)];
      return conBajas ? animales : animales.where((a) => !a.deBaja).toList();
    }
    var consulta = _db.from('fichas_bovinas').select().eq('granja_id', Granjas.instance.actual.id);
    if (!conBajas) consulta = consulta.isFilter('fecha_baja', null);
    final filas = await consulta.order('identificacion');
    return filas.map(Animal.fromMap).toList();
  }

  // 4. Animales activos: los que admiten nuevos registros.
  Future<List<Animal>> activos() => deLaGranja();

  Future<Animal> porId(String id) async {
    if (_conApi) return Animal.desdeApi(jsonDecode((await _pedir('GET', '/$id')).body) as Map<String, dynamic>);
    return Animal.fromMap(await _db.from('fichas_bovinas').select().eq('id', id).single());
  }

  Future<String?> crear(Animal animal) => _guardar(
        api: () => _pedir('POST', '', cuerpo: {...animal.paraApi(), 'granjaId': Granjas.instance.actual.id}),
        supabase: () => _db
            .from('fichas_bovinas')
            .insert({...animal.datosGenerales(), 'granja_id': Granjas.instance.actual.id}),
      );

  // 5. Se edita por id, así los registros siguen vinculados.
  Future<String?> actualizar(Animal animal) async {
    if (!Granjas.instance.sesionAdministradora && Granjas.instance.rol == RolMiembro.veterinario) return 'El veterinario solo puede editar la etapa';
    if (!Granjas.instance.sesionAdministradora && Granjas.instance.rol == RolMiembro.trabajador) {
      try {
        final actual = await porId(animal.id);
        if (actual.etapa != animal.etapa) return 'El trabajador no puede cambiar la etapa';
      } on Exception { return 'No se pudo comprobar la etapa actual'; }
    }
    return _guardar(
        api: () => _pedir('PUT', '/${animal.id}', cuerpo: animal.paraApi()),
        supabase: () => _db.from('fichas_bovinas').update(animal.datosGenerales()).eq('id', animal.id),
      );
  }

  Future<String?> actualizarEtapa(Animal animal, Etapa etapa) {
    if (animal.deBaja || (!Granjas.instance.sesionAdministradora && Granjas.instance.rol == RolMiembro.trabajador)) {
      return Future.value('Solo el dueño o veterinario pueden cambiar la etapa de una ficha activa');
    }
    return _guardar(
      api: () => _pedir('PATCH', '/${animal.id}/etapa', cuerpo: {'etapa': etapa.etiqueta}),
      supabase: () => _db.from('fichas_bovinas').update({'etapa': etapa.name}).eq('id', animal.id),
    );
  }

  Future<String?> darDeBaja(Animal animal, DateTime fecha, String motivo) {
    final dia = fecha.toIso8601String().substring(0, 10);
    return _guardar(
      api: () => _pedir('DELETE', '/${animal.id}', consulta: {'motivo': motivo.trim(), 'fecha': dia}),
      supabase: () => _db
          .from('fichas_bovinas')
          .update({'fecha_baja': dia, 'motivo_baja': motivo.trim()})
          .eq('id', animal.id),
    );
  }

  // 6. Pide a la API con el token de la sesión; un rechazo se lanza como ErrorApi.
  Future<http.Response> _pedir(String metodo, String ruta,
      {Map<String, String>? consulta, Map<String, dynamic>? cuerpo}) async {
    final direccion = Uri.parse('$_api/api/fichasbovinas$ruta').replace(queryParameters: consulta);
    final pedido = http.Request(metodo, direccion)
      ..headers['Authorization'] = 'Bearer ${_cliente?.auth.currentSession?.accessToken ?? ''}'
      ..headers['Content-Type'] = 'application/json';
    if (cuerpo != null) pedido.body = jsonEncode(cuerpo);
    // 7. El plan gratuito de Render tarda en despertar; se le da hasta un minuto.
    final respuesta = await http.Response.fromStream(await _http.send(pedido).timeout(const Duration(seconds: 60)));
    if (respuesta.statusCode >= 400) throw ErrorApi(respuesta.statusCode, utf8.decode(respuesta.bodyBytes));
    return respuesta;
  }

  // 8. Devuelve null o el mensaje de error.
  Future<String?> _guardar({required Future<Object?> Function() api, required Future<void> Function() supabase}) async {
    try {
      await (_conApi ? api() : supabase());
      return null;
    } on ErrorApi catch (e) {
      return switch (e.estado) {
        401 => 'Tu sesión venció. Volvé a iniciar sesión',
        403 => 'Tu rol no permite este cambio',
        409 => 'Ya existe un animal con esa identificación en esta granja',
        400 when e.cuerpo.contains('ya existe') => 'Ya existe un animal con esa identificación en esta granja',
        _ => 'No se pudo guardar la ficha',
      };
    } on PostgrestException catch (e) {
      return switch (e.code) {
        '23505' => 'Ya existe un animal con esa identificación en esta granja',
        '42501' => 'Tu rol no permite este cambio',
        _ => 'No se pudo guardar la ficha',
      };
    } on Exception {
      return 'No se pudo conectar. Revisa tu internet';
    }
  }
}

// 9. Respuesta de error de la API.
class ErrorApi implements Exception {
  const ErrorApi(this.estado, this.cuerpo);
  final int estado;
  final String cuerpo;
}
