// 1. Etiquetas de la app y valores del contrato supabase-render.
const tiposAtencion = {'Diagnostico': 'Diagnóstico', 'Control': 'Control', 'Evolucion': 'Evolución'};
const aptitudes = {'': 'Sin evaluar', 'NoApta': 'Todavía no apta', 'Apta': 'Apta'};
const estadosPrenez = {'NoEvaluada': 'No determinada', 'Vacia': 'No gestante', 'Prenada': 'Confirmada'};
const eventosReproductivos = {'Valoracion': 'Sin evento', 'Parto': 'Parto', 'Perdida': 'Pérdida'};

String fechaApi(DateTime fecha) => '${fecha.year.toString().padLeft(4, '0')}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')}';

// 2. Un antecedente conserva su autor, estado y datos; no reemplaza los anteriores.
class RegistroClinico {
  RegistroClinico.desdeApi(Map<String, dynamic> datos, {required this.reproductivo})
      : id = datos['id'] as String,
        animalId = datos['fichaBovinaId'] as String,
        autorId = datos['cuentaVeterinarioId'] as String,
        fecha = DateTime.parse(datos['fecha'] as String).toLocal(),
        tipo = datos['tipo'] as String,
        detalle = datos['detalle'] as String? ?? '',
        anulado = datos['anulado'] == true,
        aptitud = datos['aptitud'] as String?,
        prenez = datos['prenez'] as String?,
        proximoControl = datos['proximoControl'] as String?,
        partoProbable = datos['partoProbable'] as String?,
        version = (datos['version'] as num?)?.toInt();

  final String id, animalId, autorId, tipo, detalle;
  final DateTime fecha;
  final bool reproductivo, anulado;
  final String? aptitud, prenez, proximoControl, partoProbable;
  // RF-07: versión vista; la API rechaza la corrección si cambió mientras tanto.
  final int? version;

  String get titulo => reproductivo
      ? {'Valoracion': 'Valoración reproductiva', 'Parto': 'Parto', 'Perdida': 'Pérdida'}[tipo] ?? tipo
      : tiposAtencion[tipo] ?? tipo;
  String get aptitudTexto => aptitud == null ? 'Sin evaluar' : aptitudes[aptitud] ?? (aptitud == 'EnObservacion' ? 'En observación' : aptitud!);
  String get prenezTexto => estadosPrenez[prenez] ?? prenez ?? 'No determinada';
}
