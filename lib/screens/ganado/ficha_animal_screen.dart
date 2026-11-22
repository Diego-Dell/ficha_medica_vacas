import 'package:flutter/material.dart';

import '../../logic/granjas.dart';
import '../../models/animal.dart';
import '../../widgets/vetlink.dart';
import '../inicio_por_rol.dart';

// 1. "Lucera · 0842" del prototipo: ficha activa (05) o conservada después de la baja (06).
class FichaAnimalScreen extends StatelessWidget {
  const FichaAnimalScreen({super.key, required this.animal});

  final Animal animal;

  // 2. Aquí Clínica, Tratamientos y Cuidados agregan su historial y opciones.
  List<Widget> _registros(Animal animal) => const [];

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    final a = animal;
    final datos = [
      if (a.raza != null) a.raza!,
      if (a.nacimiento != null) 'Nacimiento: ${fechaCorta(a.nacimiento!)}${a.nacimientoEstimado ? ' (estimado)' : ''}',
    ];

    return PantallaVetLink(
      encabezado: EncabezadoVetLink(granja: Granjas.instance.actual.nombre, alVolver: () => Navigator.pop(context)),
      titulo: a.titulo,
      subtitulo: a.deBaja ? 'Ficha conservada después de la baja.' : 'Ficha e historial sanitario.',
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: a.deBaja ? colorAmbarFondo : colorVerdeSuave,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                a.deBaja ? 'De baja · ${fechaCorta(a.fechaBaja!)}' : 'Activa · ${a.etapa.etiqueta}',
                style: tema.labelLarge?.copyWith(
                  color: a.deBaja ? colorAmbarTexto : colorVerdeOscuro,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (a.deBaja || datos.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  a.deBaja ? 'Motivo: ${a.motivoBaja}.' : datos.join(' · '),
                  style: tema.bodySmall?.copyWith(color: a.deBaja ? colorAmbarTexto : colorTextoSuave),
                ),
              ],
            ],
          ),
        ),
        ..._registros(a),
        if (a.deBaja) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text('Esta ficha no admite nuevos eventos.', style: tema.bodySmall?.copyWith(color: colorTextoSuave)),
          ),
          BotonPrincipal(
            texto: 'Volver a la granja',
            alPresionar: () => Navigator.popUntil(context, (ruta) => ruta.settings.name == InicioPorRol.ruta || ruta.isFirst),
          ),
        ],
      ],
    );
  }
}
