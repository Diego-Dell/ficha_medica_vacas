enum RolMiembro {
  dueno('Dueño'),
  veterinario('Veterinario'),
  trabajador('Trabajador');

  const RolMiembro(this.etiqueta);
  final String etiqueta;
}

class Miembro {
  const Miembro({required this.nombre, required this.correo, required this.rol});

  final String nombre;
  final String correo;
  final RolMiembro rol;
}

class Invitacion {
  const Invitacion({this.nombre, required this.correo, required this.rol, required this.enviada});

  final String? nombre;
  final String correo;
  final RolMiembro rol;
  final DateTime enviada;
}
