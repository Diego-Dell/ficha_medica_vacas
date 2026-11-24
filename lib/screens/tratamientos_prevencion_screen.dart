import 'package:flutter/material.dart';

import '../logic/granjas.dart';
import '../models/animal.dart';
import '../models/miembro.dart';
import '../widgets/historial_tratamientos.dart';
import '../widgets/selector_animal.dart';
import '../widgets/vetlink.dart';

// Inicio del módulo: indicaciones y controles del animal seleccionado.
class TratamientosPrevencionScreen extends StatefulWidget {
  const TratamientosPrevencionScreen({super.key});
  @override
  State<TratamientosPrevencionScreen> createState() =>
      _TratamientosPrevencionScreenState();
}

class _TratamientosPrevencionScreenState
    extends State<TratamientosPrevencionScreen> {
  Animal? _animal;

  @override
  Widget build(BuildContext context) => PantallaVetLink(
    titulo: 'Tratamientos y prevención',
    subtitulo: Granjas.instance.sesionAdministradora || Granjas.instance.rol == RolMiembro.veterinario
        ? 'Indicá tratamientos y programá los cuidados preventivos.'
        : 'Consultá las indicaciones y los controles del animal.',
    encabezado: EncabezadoVetLink(
      granja:
          '${Granjas.instance.actual.nombre} · ${Granjas.instance.rol.etiqueta}',
    ),
    children: [
      SelectorAnimal(alElegir: (animal) => setState(() => _animal = animal)),
      if (_animal == null)
        const AvisoVetLink(
          titulo: 'Elegí un animal para ver sus tratamientos y prevención.',
        ),
      if (_animal != null)
        HistorialTratamientos(key: ValueKey(_animal!.id), animal: _animal!),
    ],
  );
}
