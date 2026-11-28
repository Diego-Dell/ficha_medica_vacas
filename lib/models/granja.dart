class Granja {
  const Granja({
    this.id = '',
    required this.nombre,
    required this.dueno,
    required this.superficie,
    required this.runsa,
    required this.documento,
    this.confirmada = false,
    this.motivoRechazo,
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
        motivoRechazo: fila['motivo_rechazo'] as String?,
      );

  final String id;
  final String nombre;
  final String dueno;
  final double superficie;
  final String runsa;

  /// 2. Guarda la referencia pendiente o la ruta privada del documento.
  final String documento;
  final bool confirmada;
  final String? motivoRechazo;
  bool get rechazada => !confirmada && motivoRechazo != null;

  /// 3. Copia la granja con otro RUNSA.
  Granja conRunsa(String nuevo) => Granja(
        id: id,
        nombre: nombre,
        dueno: dueno,
        superficie: superficie,
        runsa: nuevo,
        documento: documento,
        confirmada: confirmada,
        motivoRechazo: motivoRechazo,
      );
}
