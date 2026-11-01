/// Sesión del usuario (Singleton): toda la app comparte la misma instancia.
class Sesion {
  Sesion._();
  static final instance = Sesion._();

  // Usuario de demostración: aún no hay un sistema real de usuarios.
  static const _usuarioDemo = 'admin';
  static const _contrasenaDemo = 'admin123';

  String? _usuario;

  String? get usuario => _usuario;

  bool get iniciada => _usuario != null;

  /// Devuelve true si las credenciales son correctas e inicia la sesión.
  bool iniciar(String usuario, String contrasena) {
    final nombre = usuario.trim();
    if (nombre != _usuarioDemo || contrasena != _contrasenaDemo) return false;
    _usuario = nombre;
    return true;
  }
}
