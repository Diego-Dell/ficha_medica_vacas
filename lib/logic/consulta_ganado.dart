import '../models/animal.dart';
import '../models/prevencion.dart';
import '../models/registro_clinico.dart';

/// Última valoración de cada tipo. Una valoración posterior sin aptitud no
/// borra la última aptitud registrada, y lo mismo ocurre con la preñez.
class ValoracionAnimal {
  const ValoracionAnimal({this.aptitud, this.prenez});

  final RegistroClinico? aptitud;
  final RegistroClinico? prenez;

  String get estadoAptitud => aptitud?.aptitud ?? '';
  String get estadoPrenez => prenez?.prenez ?? 'NoEvaluada';
  String get aptitudTexto => aptitud?.aptitudTexto ?? 'Sin evaluar';
  String get prenezTexto => prenez?.prenezTexto ?? 'No determinada';
}

Map<String, ValoracionAnimal> valoracionesPorAnimal(
  List<Animal> animales,
  List<RegistroClinico> eventos,
) {
  final ids = animales.map((a) => a.id).toSet();
  final ordenados = eventos.where((e) =>
      ids.contains(e.animalId) && e.reproductivo && !e.anulado).toList()
    ..sort((a, b) => b.fecha.compareTo(a.fecha));
  final resultado = <String, ValoracionAnimal>{};
  for (final evento in ordenados) {
    final anterior = resultado[evento.animalId] ?? const ValoracionAnimal();
    resultado[evento.animalId] = ValoracionAnimal(
      aptitud: anterior.aptitud ?? (evento.aptitud == null ? null : evento),
      prenez: anterior.prenez ?? (evento.prenez == null ? null : evento),
    );
  }
  return resultado;
}

List<Animal> filtrarGanado(
  List<Animal> animales,
  Map<String, ValoracionAnimal> valoraciones, {
  String busqueda = '',
  Etapa? etapa,
  String? aptitud,
  String? prenez,
}) {
  final texto = busqueda.trim().toLowerCase();
  return [
    for (final animal in animales)
      if ((etapa == null || animal.etapa == etapa) &&
          (aptitud == null ||
              (valoraciones[animal.id]?.estadoAptitud ?? '') == aptitud) &&
          (prenez == null ||
              (valoraciones[animal.id]?.estadoPrenez ?? 'NoEvaluada') == prenez) &&
          (texto.isEmpty ||
              animal.arete.toLowerCase().contains(texto) ||
              (animal.nombre ?? '').toLowerCase().contains(texto)))
        animal,
  ];
}

/// Avisos visibles exclusivamente para animales activos de la granja cargada.
class AvisoGanado {
  const AvisoGanado({required this.animal, required this.prevencion, required this.vencido});

  final Animal animal;
  final Prevencion prevencion;
  final bool vencido;
}

List<AvisoGanado> avisosDeGranja(
  List<Animal> animales,
  List<Prevencion> prevenciones, {
  DateTime? hoy,
}) {
  final activos = {for (final a in animales) if (!a.deBaja) a.id: a};
  final fechaActual = hoy ?? DateTime.now();
  final diaActual = DateTime(fechaActual.year, fechaActual.month, fechaActual.day);
  final avisos = [
    for (final p in prevenciones)
      if (p.pendiente &&
          (p.tipo == 'Vacuna' || p.esControl) &&
          activos.containsKey(p.animalId))
        AvisoGanado(
          animal: activos[p.animalId]!,
          prevencion: p,
          vencido: DateTime(p.fecha.year, p.fecha.month, p.fecha.day)
              .isBefore(diaActual),
        ),
  ];
  avisos.sort((a, b) {
    if (a.vencido != b.vencido) return a.vencido ? -1 : 1;
    return a.prevencion.fecha.compareTo(b.prevencion.fecha);
  });
  return avisos;
}
