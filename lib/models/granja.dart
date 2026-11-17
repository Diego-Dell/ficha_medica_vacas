class Granja {
  const Granja({
    this.id = '',
    required this.nombre,
    required this.dueno,
    required this.superficie,
    required this.runsa,
    required this.documento,
    this.confirmada = false,
  });

  /// 1. Crea la granja a partir de una fila de Supabase.
  factory Granja.fromMap(Map<String, dynamic> fila, {required String dueno}) => Granja(
        id: fila['id'] as String,
        nombre: fila['nombre'] as String,
        dueno: dueno,
        superficie: (fila['hectareas'] as num).toDouble(),
        runsa: fila['runsa'] as String,
        documento: fila['documentos_terreno'] as String? ?? '',
        confirmada: fila['confirmada'] as bool,
      );

  final String id;
  final String nombre;
  final String dueno;
  final double superficie;
  final String runsa;

  /// 2. Guarda el nombre del archivo con la documentación del terreno.
  final String documento;
  final bool confirmada;
}
