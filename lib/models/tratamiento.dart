import 'registro_clinico.dart';

// La indicación original se conserva cuando se reemplaza o finaliza.
class Tratamiento {
  Tratamiento.fromMap(Map<String, dynamic> fila)
    : id = fila['id'] as String,
      animalId = _valor(fila, 'ficha_id', 'fichaBovinaId') as String,
      atencionId = _valor(fila, 'atencion_id', 'atencionClinicaId') as String,
      autorId = _valor(fila, 'prescrito_por', 'cuentaVeterinarioId') as String,
      medicamento = fila['medicamento'] as String,
      dosis = (fila['dosis'] as num).toDouble(),
      unidad = fila['unidad'] as String,
      via = fila['via'] as String,
      frecuencia = fila['frecuencia'] as String,
      inicio = DateTime.parse(fila['inicio'] as String),
      duracion = fila['duracion'] as String,
      retiro = fila['retiro'] as String?,
      fechaFin = _valor(fila, 'fecha_fin', 'fechaFin') == null
          ? null
          : DateTime.parse(_valor(fila, 'fecha_fin', 'fechaFin') as String),
      motivoFin = _valor(fila, 'motivo_fin', 'motivoFin') as String?,
      anteriorId = _valor(fila, 'anterior_id', 'anteriorId') as String?,
      anulado = fila['anulado'] == true,
      version = fila['version'] as int? ?? 1;

  static dynamic _valor(Map<String, dynamic> fila, String base, String api) =>
      fila.containsKey(base) ? fila[base] : fila[api];

  final String id, animalId, atencionId, autorId;
  final String medicamento, unidad, via, frecuencia, duracion;
  final double dosis;
  final DateTime inicio;
  final DateTime? fechaFin;
  final String? motivoFin, retiro, anteriorId;
  final bool anulado;
  final int version;

  bool get vigente => !anulado && fechaFin == null;
  String get estado => anulado
      ? 'Anulado'
      : vigente
      ? 'Vigente'
      : 'Finalizado';
}

// Datos editables de una nueva indicación; el autor se toma de la sesión.
class IndicacionTratamiento {
  const IndicacionTratamiento({
    required this.medicamento,
    required this.dosis,
    required this.unidad,
    required this.via,
    required this.frecuencia,
    required this.inicio,
    required this.duracion,
    this.retiro,
  });

  final String medicamento, unidad, via, frecuencia, duracion;
  final double dosis;
  final DateTime inicio;
  final String? retiro;

  String? validar() {
    if ([
      medicamento,
      unidad,
      via,
      frecuencia,
      duracion,
    ].any((s) => s.trim().isEmpty)) {
      return 'Completá los datos obligatorios del tratamiento';
    }
    if (!dosis.isFinite || dosis < .001 || dosis > 9999999.999) {
      return 'Ingresá una dosis entre 0,001 y 9999999,999';
    }
    if (unidad.trim().length > 30 ||
        via.trim().length > 60 ||
        frecuencia.trim().length > 100 ||
        duracion.trim().length > 100 ||
        medicamento.trim().length > 200 ||
        (retiro?.trim().length ?? 0) > 500) {
      return 'Revisá la longitud de los campos';
    }
    return null;
  }

  Map<String, dynamic> toMap() => {
    'medicamento': medicamento.trim(),
    'dosis': dosis,
    'unidad': unidad.trim(),
    'via': via.trim(),
    'frecuencia': frecuencia.trim(),
    'inicio': fechaApi(inicio),
    'duracion': duracion.trim(),
    'retiro': retiro?.trim().isEmpty == true ? null : retiro?.trim(),
  };
}
