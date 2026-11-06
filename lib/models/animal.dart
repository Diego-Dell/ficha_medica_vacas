class Animal {
  const Animal({required this.id, this.nombre, required this.arete, required this.categoria, this.raza});

  /// 1. Crea el animal a partir de una ficha de Supabase.
  factory Animal.fromMap(Map<String, dynamic> fila) => Animal(
        id: fila['id'] as String,
        nombre: fila['nombre'] as String?,
        arete: fila['identificacion'] as String,
        categoria: _categoria(fila['etapa'] as String),
        raza: fila['raza'] as String?,
      );

  final String id;
  final String? nombre;
  final String arete;
  final String categoria;
  final String? raza;

  /// 2. Escribe el nombre con el arete, o solo el arete si no tiene nombre.
  String get titulo => nombre == null ? arete : '$nombre · $arete';

  /// 3. Convierte la etapa de la tabla en el texto que se muestra.
  static String _categoria(String etapa) => '${etapa[0].toUpperCase()}${etapa.substring(1)}';
}
