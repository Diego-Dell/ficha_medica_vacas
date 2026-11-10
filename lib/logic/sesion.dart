import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/granja.dart';
import 'api.dart';

<<<<<<< HEAD
/// 1. Comparte una sola sesión en toda la app (Singleton) y esconde los detalles de Supabase Auth detrás de métodos simples (Facade).
=======
>>>>>>> bb40139 (feat: integrar backend propio y flujos de acceso VetLink)
class Sesion {
  Sesion._();
  static final instance = Sesion._();

  static const _url = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://localhost:3001',
  );
  static const _claveToken = 'vetlink.session.token';
  static const _claveId = 'vetlink.session.id';
  static const _claveCorreo = 'vetlink.session.email';
  static const _claveNombre = 'vetlink.session.name';

  Api _api = Api(url: _url);
  SharedPreferences? _preferencias;
  String? _id;
  String? _usuario;
  String? _nombre;
  String? _token;

  Api get api => _api;
  @visibleForTesting
  set api(Api value) => _api = value;

  String? get id => _id;
  String? get usuario => _usuario;
  String get nombre => _nombre ?? _usuario ?? '';
  String? get token => _token;
  bool get iniciada => _token != null;

  Future<void> inicializar() async {
    _preferencias = await SharedPreferences.getInstance();
    _token = _preferencias!.getString(_claveToken);
    _id = _preferencias!.getString(_claveId);
    _usuario = _preferencias!.getString(_claveCorreo);
    _nombre = _preferencias!.getString(_claveNombre);
    _api.token = _token;
  }

  Future<String?> iniciar(String correo, String contrasena) async {
    try {
      final respuesta = await _api.pedir(
        '/auth/login',
        metodo: 'POST',
        datos: {'email': correo.trim(), 'password': contrasena},
      ) as Map<String, dynamic>;
      final usuario = respuesta['user'] as Map<String, dynamic>;
      _token = respuesta['access_token'] as String;
      _id = usuario['id'] as String;
      _usuario = usuario['email'] as String;
      _nombre = usuario['nombre'] as String?;
      _api.token = _token;
      await _guardarSesion();
      return null;
    } on ApiException catch (error) {
      return error.mensaje;
    } catch (_) {
      return 'No se pudo conectar al servidor. Revisa tu internet';
    }
  }

  Future<String?> cerrar() async {
    try {
      if (_token != null) {
        await _api.pedir('/logout', metodo: 'POST', datos: const {});
      }
    } catch (_) {
      // La sesión local se elimina aunque el servidor no esté disponible.
    }
    _token = null;
    _id = null;
    _usuario = null;
    _nombre = null;
    _api.token = null;
    final preferencias = _preferencias ?? await SharedPreferences.getInstance();
    await preferencias.remove(_claveToken);
    await preferencias.remove(_claveId);
    await preferencias.remove(_claveCorreo);
    await preferencias.remove(_claveNombre);
    return null;
  }

  Future<String?> recuperar(String correo) async {
    try {
      await _api.pedir(
        '/auth/recuperar',
        metodo: 'POST',
        datos: {'email': correo.trim()},
      );
      return null;
    } on ApiException catch (error) {
      return error.mensaje;
    } catch (_) {
      return 'No se pudo conectar al servidor. Revisa tu internet';
    }
  }

  Future<String?> confirmarCorreo(String token) async {
    try {
      await _api.pedir(
        '/auth/confirmar',
        metodo: 'POST',
        datos: {'token': token},
      );
      return null;
    } on ApiException catch (error) {
      return error.mensaje;
    } catch (_) {
      return 'No se pudo confirmar el correo. Revisa tu internet';
    }
  }

  Future<String?> restablecer(String token, String contrasena) async {
    try {
      await _api.pedir(
        '/auth/restablecer',
        metodo: 'POST',
        datos: {'token': token, 'password': contrasena},
      );
      return null;
    } on ApiException catch (error) {
      return error.mensaje;
    } catch (_) {
      return 'No se pudo actualizar la contraseña. Revisa tu internet';
    }
  }

  Future<String?> registrar(String correo, String contrasena, Granja granja) =>
      _registrar(correo, contrasena, {
        'nombre': granja.dueno,
        'granja': granja.nombre,
        'superficie': granja.superficie,
        'runsa': granja.runsa,
        'documento': granja.documento,
      });

  Future<String?> crearCuentaInvitada(
    String nombre,
    String correo,
    String contrasena,
  ) => _registrar(correo, contrasena, {'nombre': nombre.trim()});

  Future<String?> _registrar(
    String correo,
    String contrasena,
    Map<String, dynamic> datos,
  ) async {
    try {
      await _api.pedir(
        '/auth/registro',
        metodo: 'POST',
        datos: {'email': correo.trim(), 'password': contrasena, 'data': datos},
      );
      return null;
    } on ApiException catch (error) {
      return error.mensaje;
    } catch (_) {
      return 'No se pudo conectar al servidor. Revisa tu internet';
    }
  }

  Future<void> _guardarSesion() async {
    final preferencias = _preferencias ?? await SharedPreferences.getInstance();
    _preferencias = preferencias;
    await preferencias.setString(_claveToken, _token!);
    await preferencias.setString(_claveId, _id!);
    await preferencias.setString(_claveCorreo, _usuario!);
    if (_nombre != null) await preferencias.setString(_claveNombre, _nombre!);
    _api.token = _token;
  }
}
