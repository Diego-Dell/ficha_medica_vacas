import 'package:flutter/material.dart';

import '../logic/fichas.dart';
import '../logic/granjas.dart';
import '../models/animal.dart';
import 'vetlink.dart';

/// Campo para elegir un animal activo de la granja actual; lo comparten Clínica, Tratamientos y Cuidados.
class SelectorAnimal extends StatefulWidget {
  const SelectorAnimal({super.key, required this.alElegir, this.inicial});

  final ValueChanged<Animal> alElegir;

  /// Animal ya elegido, por ejemplo cuando se llega desde su ficha.
  final Animal? inicial;

  @override
  State<SelectorAnimal> createState() => _SelectorAnimalState();
}

class _SelectorAnimalState extends State<SelectorAnimal> {
  late Future<List<Animal>> _animales = Fichas.instance.activos();
  late String? _id = widget.inicial?.id;

  /// 1. Vuelve a pedir los animales activos.
  void _recargar() {
    setState(() {
      _animales = Fichas.instance.activos();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Animal>>(
      future: _animales,
      builder: (context, estado) {
        if (estado.hasError) {
          return TextButton(
            style: TextButton.styleFrom(foregroundColor: colorRojo),
            onPressed: _recargar,
            child: const Text('No se pudieron cargar los animales. Reintentar'),
          );
        }
        final animales = estado.data;
        if (animales == null) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        // 2. Solo ofrece animales activos: un animal dado de baja no admite nuevos eventos.
        return CampoEtiquetado(
          etiqueta: 'Animal de ${Granjas.instance.actual.nombre} *',
          child: DropdownButtonFormField<String>(
            initialValue: animales.any((a) => a.id == _id) ? _id : null,
            isExpanded: true,
            decoration: decoracionCampo(pista: animales.isEmpty ? 'No hay animales activos' : 'Elegir animal'),
            items: [for (final a in animales) DropdownMenuItem(value: a.id, child: Text(a.titulo))],
            onChanged: (id) {
              setState(() => _id = id);
              widget.alElegir(animales.firstWhere((a) => a.id == id));
            },
            validator: (id) => id == null ? 'Elegí un animal' : null,
          ),
        );
      },
    );
  }
}
