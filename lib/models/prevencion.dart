const tiposPrevencion = {
  'Vacuna': 'Vacuna',
  'Desparasitacion': 'Desparasitación',
  'Control': 'Control',
};

class Prevencion {
  Prevencion.fromMap(Map<String, dynamic> fila)
    : id = fila['id'] as String,
      animalId = _valor(fila, 'ficha_id', 'fichaBovinaId') as String,
      autorId = _valor(fila, 'programado_por', 'cuentaVeterinarioId') as String,
      tipo = fila['tipo'] as String,
      nombre = fila['nombre'] as String,
      fecha = DateTime.parse(
        _valor(fila, 'fecha_programada', 'fechaProgramada') as String,
      ),
      estado = fila['estado'] as String,
      realizada = _valor(fila, 'fecha_realizacion', 'fechaRealizacion') == null
          ? null
          : DateTime.parse(
              _valor(fila, 'fecha_realizacion', 'fechaRealizacion') as String,
            ).toLocal(),
      version = fila['version'] as int? ?? 1;

  static dynamic _valor(Map<String, dynamic> fila, String base, String api) =>
      fila.containsKey(base) ? fila[base] : fila[api];

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
