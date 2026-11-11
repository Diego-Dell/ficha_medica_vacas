import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/granja.dart';
import 'granjas.dart';

/// 1. Comparte una sola sesión en toda la app (Singleton) y esconde los detalles de Supabase Auth detrás de métodos simples (Facade).
class Sesion {
  Sesion._();
  static final instance = Sesion._();

  // 2. Lee la URL y la clave pública de config.json al compilar.
  static const _url = String.fromEnvironment('SUPABASE_URL');
  static const _clavePublica = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  /// Enlaces que abren la app desde los correos de Supabase Auth; deben estar en Redirect URLs de Supabase.
  static const enlaceRecuperacion = 'vetlink://restablecer';
  static const enlaceConfirmacion = 'vetlink://confirmar';

  GoTrueClient? _auth;

  /// Pantalla del último enlace del correo que abrió la app, mientras su resultado no se atienda.
  String? _enlace;

  /// Códigos de enlace ya validados, para no gastar dos veces el mismo.
  final _tokensAtendidos = <String>{};

  /// Quién muestra los enlaces que fallan y el aviso que llegó antes de que alguien escuchara.
  ValueChanged<String>? _alFallar;
  String? _falloPendiente;

  static const _enlaceVencido = 'El enlace venció o ya se usó. Pedí uno nuevo';

  /// 3. Conecta con Supabase; sin configuración nadie puede iniciar sesión.
  Future<void> inicializar() async {
    if (_url.isEmpty || _clavePublica.isEmpty) return;
    await Supabase.initialize(
      url: _url,
      publishableKey: _clavePublica,
      authOptions: FlutterAuthClientOptions(detectSessionInUriPredicate: recordarEnlace),
    );
    _auth = Supabase.instance.client.auth;
    Granjas.instance.conectar(Supabase.instance.client);

    // 3.2. Escucha los enlaces con token_hash; el que abrió la app llega antes de escuchar, así que se pide aparte.
    final enlaces = AppLinks();
    enlaces.uriLinkStream.listen(atenderEnlace);
    final inicial = await enlaces.getInitialLink();
    if (inicial != null) unawaited(atenderEnlace(inicial));
  }

  /// 3.3. Valida el token_hash que trae el enlace; llega desde la función abrir-cuenta, que solo redirige para que ningún revisor de correo lo gaste.
  Future<void> atenderEnlace(Uri uri) async {
    final token = uri.queryParameters['token_hash'];
    final auth = _auth;
    if (token == null || auth == null || !_tokensAtendidos.add(token)) return;
    _enlace = uri.host;
    try {
      final tipo = uri.queryParameters['type'] == 'recovery' ? OtpType.recovery : OtpType.email;
      await auth.verifyOTP(tokenHash: token, type: tipo);
    } on Exception {
      _enlace = null;
      _avisarFallo(_enlaceVencido);
    }
  }

  /// 3.4. Entrega el aviso de un enlace fallido o lo guarda hasta que alguien escuche.
  void _avisarFallo(String mensaje) {
    final alFallar = _alFallar;
    if (alFallar == null) {
      _falloPendiente = mensaje;
    } else {
      alFallar(mensaje);
    }
  }

  /// 3.1. Anota qué enlace del correo abrió la app y le dice a Supabase si trae datos de sesión.
  @visibleForTesting
  bool recordarEnlace(Uri uri) {
    final fragmento = Uri.splitQueryString(uri.fragment);
    bool tiene(String clave) => uri.queryParameters.containsKey(clave) || fragmento.containsKey(clave);
    final deSesion = ['code', 'access_token', 'error', 'error_description'].any(tiene);
    if (deSesion) _enlace = uri.host;
    return deSesion;
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
      await auth.resetPasswordForEmail(correo.trim(), redirectTo: enlaceRecuperacion);
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
      await auth.signUp(email: correo.trim(), password: contrasena, data: datos, emailRedirectTo: enlaceConfirmacion);
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

  /// 9. Avisa cuando la app se abre desde el enlace de recuperación (patrón Observer).
  StreamSubscription<AuthState>? alRecuperar(VoidCallback accion) =>
      _auth?.onAuthStateChange.where((estado) => estado.event == AuthChangeEvent.passwordRecovery).listen((_) {
        _enlace = null;
        accion();
      }, onError: (Object _) {});

  /// 10. Guarda la nueva contraseña de la sesión abierta por el enlace; devuelve null o el mensaje de error.
  Future<String?> cambiarContrasena(String contrasena) async {
    final auth = _auth;
    if (auth == null) return 'La app no está configurada';
    try {
      await auth.updateUser(UserAttributes(password: contrasena));
      return null;
    } on AuthRetryableFetchException {
      return 'No se pudo conectar. Revisa tu internet';
    } on AuthException catch (e) {
      return switch (e.code) {
        'same_password' => 'La nueva contraseña debe ser distinta de la anterior',
        'weak_password' => 'La contraseña es muy débil',
        'session_not_found' || 'session_expired' => 'El enlace venció. Pedí uno nuevo',
        _ => 'No se pudo guardar la contraseña',
      };
    }
  }

  /// 11. Cierra la sesión; si no hay conexión, igual la olvida en este dispositivo.
  Future<void> cerrar() async {
    try {
      await _auth?.signOut();
    } on Exception {
      return;
    }
  }

  /// 12. Avisa cuando el enlace de confirmación abre la app o cuando un enlace del correo ya no sirve (patrón Observer).
  StreamSubscription<AuthState>? alAbrirEnlace({
    required VoidCallback alConfirmar,
    required ValueChanged<String> alFallar,
  }) {
    _alFallar = alFallar;
    final pendiente = _falloPendiente;
    _falloPendiente = null;
    if (pendiente != null) alFallar(pendiente);
    return _auth?.onAuthStateChange.listen(
      (estado) {
        if (estado.event != AuthChangeEvent.signedIn || _enlace != 'confirmar') return;
        _enlace = null;
        alConfirmar();
      },
      onError: (Object _) {
        if (_enlace == null) return;
        _enlace = null;
        _avisarFallo(_enlaceVencido);
      },
    );
  }
}
