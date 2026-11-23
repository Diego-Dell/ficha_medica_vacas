const tiposPrevencion = {
  'Vacuna': 'Vacuna',
  'Desparasitacion': 'Desparasitación',
  'Control': 'Control',
};

class Prevencion {
  Prevencion.fromMap(Map<String, dynamic> fila)
    : id = fila['id'] as String,
      animalId = fila['ficha_id'] as String,
      autorId = fila['programado_por'] as String,
      tipo = fila['tipo'] as String,
      nombre = fila['nombre'] as String,
      fecha = DateTime.parse(fila['fecha_programada'] as String),
      estado = fila['estado'] as String,
      realizada = fila['fecha_realizacion'] == null
          ? null
          : DateTime.parse(fila['fecha_realizacion'] as String).toLocal(),
      version = fila['version'] as int? ?? 1;

  final String id, animalId, autorId, tipo, nombre, estado;
  final DateTime fecha;
  final DateTime? realizada;
  final int version;
  bool get pendiente => estado.toLowerCase() == 'pendiente';
  bool get esControl => tipo.toLowerCase() == 'control';
  String get tipoTexto =>
      tiposPrevencion.entries
          .where((e) => e.key.toLowerCase() == tipo.toLowerCase())
          .firstOrNull
          ?.value ??
      tipo;
  String get estadoTexto => switch (estado.toLowerCase()) {
    'pendiente' => 'Pendiente',
    'realizada' => 'Realizado',
    'cancelada' => 'Cancelado',
    _ => estado,
  };
}
