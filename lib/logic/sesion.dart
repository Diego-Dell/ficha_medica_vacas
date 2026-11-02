import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Sesión del usuario (Singleton): toda la app comparte la misma instancia.
class Sesion {
  Sesion._();
  static final instance = Sesion._();

  // Definidos en config.json al compilar.
  static const _url = String.fromEnvironment('SUPABASE_URL');
  static const _clavePublica = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  GoTrueClient? _auth;

  /// Conecta con Supabase. Sin configuración nadie puede iniciar sesión.
  Future<void> inicializar() async {
    if (_url.isEmpty || _clavePublica.isEmpty) return;
    await Supabase.initialize(url: _url, publishableKey: _clavePublica);
    _auth = Supabase.instance.client.auth;
  }

  @visibleForTesting
  set auth(GoTrueClient cliente) => _auth = cliente;

  String? get usuario => _auth?.currentUser?.email;

  bool get iniciada => _auth?.currentSession != null;

  /// Envía el enlace de recuperación. Devuelve null si todo salió bien o el mensaje de error.
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

  /// Inicia la sesión. Devuelve null si todo salió bien o el mensaje de error.
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
