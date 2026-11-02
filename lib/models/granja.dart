class Granja {
  const Granja({
    required this.nombre,
    required this.dueno,
    required this.superficie,
    required this.runsa,
    required this.documento,
  });

  final String nombre;
  final String dueno;
  final double superficie;
  final String runsa;

  /// 1. Guarda el nombre del archivo con la documentación del terreno.
  final String documento;
}
