import 'package:flutter/material.dart';

import '../models/granja.dart';
import '../widgets/vetlink.dart';

class GranjaRevisionScreen extends StatelessWidget {
  const GranjaRevisionScreen({super.key, required this.granja});

  final Granja granja;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    return PantallaVetLink(
      titulo: 'Granja en revisión',
      subtitulo: 'Recibimos el registro de ${granja.nombre}.',
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: colorAmbarFondo, borderRadius: BorderRadius.circular(10)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pendiente de confirmación',
                style: tema.labelLarge?.copyWith(color: colorAmbarTexto, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                'El administrador revisará los datos y la documentación antes de habilitar el acceso.',
                style: tema.bodySmall?.copyWith(color: colorAmbarTexto),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: colorBorde),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                granja.nombre,
                style: tema.titleSmall?.copyWith(color: colorVerdeOscuro, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              for (final dato in ['Dueño: ${granja.dueno}', 'RUNSA: ${granja.runsa}', 'Documentación recibida'])
                Text(dato, style: tema.bodySmall?.copyWith(color: colorTextoSuave)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Una vez confirmada, podrás entrar a tu granja e invitar al equipo.',
          style: tema.bodySmall?.copyWith(color: colorTextoSuave),
        ),
        const SizedBox(height: 12),
        BotonSecundario(
          texto: 'Volver al login',
          alPresionar: () => Navigator.popUntil(context, (ruta) => ruta.isFirst),
        ),
      ],
    );
  }
}
