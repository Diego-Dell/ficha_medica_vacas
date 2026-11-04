import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/granja.dart';
import 'granjas.dart';

/// 1. Comparte una sola sesión en toda la app (Singleton).
class Sesion {
  Sesion._();
  static final instance = Sesion._();

  // 2. Lee la URL y la clave pública de config.json al compilar.
  static const _url = String.fromEnvironment('SUPABASE_URL');
  static const _clavePublica = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  GoTrueClient? _auth;

  /// 3. Conecta con Supabase; sin configuración nadie puede iniciar sesión.
  Future<void> inicializar() async {
    if (_url.isEmpty || _clavePublica.isEmpty) return;
    await Supabase.initialize(url: _url, publishableKey: _clavePublica);
    _auth = Supabase.instance.client.auth;
    Granjas.instance.conectar(Supabase.instance.client);
  }

  @visibleForTesting
  set auth(GoTrueClient cliente) => _auth = cliente;

  String? get id => _auth?.currentUser?.id;

  String? get usuario => _auth?.currentUser?.email;

  /// 4. Devuelve el nombre registrado o, si no tiene, el correo.
  String get nombre => _auth?.currentUser?.userMetadata?['nombre'] as String? ?? usuario ?? '';

  bool get iniciada => _auth?.currentSession != null;

  /// 5. Envía el enlace de recuperación; devuelve null o el mensaje de error.
  Future<String?> recuperar(String correo) async {
    final auth = _auth;
    if (auth == null) return 'La app no está configurada';
    try {
      await auth.resetPasswordForEmail(correo.trim());
      return null;
    } on AuthRetryableFetchException {
      return 'No se pudo conectar. Revisa tu internet';
    } on AuthException catch (e) {
      return e.code == 'over_email_send_rate_limit'
          ? 'Se enviaron demasiados correos. Intenta más tarde'
          : 'No se pudo enviar el enlace';
    }
  }

  /// 6. Crea la cuenta del dueño con los datos de su granja; devuelve null o el mensaje de error.
  Future<String?> registrar(String correo, String contrasena, Granja granja) => _crearCuenta(correo, contrasena, {
        'nombre': granja.dueno,
        'granja': granja.nombre,
        'superficie': granja.superficie,
        'runsa': granja.runsa,
        'documento': granja.documento,
      });

  /// 7. Crea la cuenta de una persona invitada, sin granja propia; devuelve null o el mensaje de error.
  Future<String?> crearCuentaInvitada(String nombre, String correo, String contrasena) =>
      _crearCuenta(correo, contrasena, {'nombre': nombre.trim()});

  Future<String?> _crearCuenta(String correo, String contrasena, Map<String, dynamic> datos) async {
    final auth = _auth;
    if (auth == null) return 'La app no está configurada';
    try {
      await auth.signUp(email: correo.trim(), password: contrasena, data: datos);
      return null;
    } on AuthRetryableFetchException {
      return 'No se pudo conectar. Revisa tu internet';
    } on AuthException catch (e) {
      return switch (e.code) {
        'user_already_exists' || 'email_exists' => 'Ya existe una cuenta con ese correo',
        'weak_password' => 'La contraseña es muy débil',
        'over_email_send_rate_limit' => 'Se enviaron demasiados correos. Intenta más tarde',
        _ => 'No se pudo completar el registro',
      };
    }
  }

  /// 8. Inicia la sesión; devuelve null o el mensaje de error.
  Future<String?> iniciar(String correo, String contrasena) async {
    final auth = _auth;
    if (auth == null) return 'La app no está configurada';
    try {
      await auth.signInWithPassword(email: correo.trim(), password: contrasena);
      return null;
    } on AuthRetryableFetchException {
      return 'No se pudo conectar. Revisa tu internet';
    } on AuthException catch (e) {
      return switch (e.code) {
        'invalid_credentials' => 'Correo o contraseña incorrectos',
        'email_not_confirmed' => 'Falta confirmar el correo',
        _ => 'No se pudo iniciar sesión',
      };
    }
  }
}
