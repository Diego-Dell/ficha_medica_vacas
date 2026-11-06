enum RolMiembro {
  dueno('Dueño'),
  veterinario('Veterinario'),
  trabajador('Trabajador');

  const RolMiembro(this.etiqueta);
  final String etiqueta;
}

class Miembro {
  const Miembro({required this.nombre, required this.correo, required this.rol});

  /// 1. Crea el miembro a partir de una vinculación de Supabase; sin nombre registrado usa el correo.
  factory Miembro.fromMap(Map<String, dynamic> fila) {
    final cuenta = fila['cuentas'] as Map<String, dynamic>;
    final correo = cuenta['identificador'] as String;
    return Miembro(
      nombre: cuenta['nombre'] as String? ?? correo,
      correo: correo,
      rol: RolMiembro.values.byName(fila['rol'] as String),
    );
  }

  final String nombre;
  final String correo;
  final RolMiembro rol;
}

class Invitacion {
  const Invitacion({this.id = '', required this.correo, required this.rol, required this.enviada});

  /// 2. Crea la invitación a partir de una fila de Supabase.
  factory Invitacion.fromMap(Map<String, dynamic> fila) => Invitacion(
        id: fila['id'] as String,
        correo: fila['correo'] as String,
        rol: RolMiembro.values.byName(fila['rol'] as String),
        enviada: DateTime.parse(fila['enviada_en'] as String).toLocal(),
      );

  final String id;
  final String correo;
  final RolMiembro rol;
  final DateTime enviada;
}
