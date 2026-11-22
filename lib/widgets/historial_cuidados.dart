import 'package:flutter/material.dart';

import '../logic/cuidados.dart';
import '../models/animal.dart';
import 'vetlink.dart';

/// Aplicaciones registradas que permanecen visibles en la ficha del animal.
class HistorialCuidados extends StatefulWidget {
  const HistorialCuidados({super.key, required this.animal});
  final Animal animal;

  @override
  State<HistorialCuidados> createState() => _HistorialCuidadosState();
}

class _HistorialCuidadosState extends State<HistorialCuidados> {
  late Future<List<AplicacionCuidado>> _aplicaciones = Cuidados.instance
      .aplicacionesDe(widget.animal);

  @override
  Widget build(BuildContext context) => FutureBuilder<List<AplicacionCuidado>>(
    future: _aplicaciones,
    builder: (context, estado) {
      if (estado.hasError) {
        return TextButton(
          onPressed: () => setState(
            () =>
                _aplicaciones = Cuidados.instance.aplicacionesDe(widget.animal),
          ),
          child: const Text(
            'No se pudieron cargar las aplicaciones. Reintentar',
          ),
        );
      }
      final aplicaciones = estado.data;
      if (aplicaciones == null) {
        return const Center(child: CircularProgressIndicator());
      }
      if (aplicaciones.isEmpty) {
        return const SizedBox.shrink();
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Aplicaciones', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          for (final a in aplicaciones) ...[
            Tarjeta(
              child: Row(
                children: [
                  const BurbujaIcono('medicamento'),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${a.dosis} ${a.unidad}',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                        Text(
                          fechaCorta(a.fecha.toLocal()),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (a.observacion?.isNotEmpty == true)
                          Text(
                            a.observacion!,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
      );
    },
  );
}
