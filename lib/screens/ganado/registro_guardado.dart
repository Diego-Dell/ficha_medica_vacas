import 'package:flutter/material.dart';

import '../../logic/granjas.dart';
import '../../widgets/vetlink.dart';

// 1. Ventana "Registro guardado" del prototipo (06 · Estados y ventanas).
Future<void> mostrarRegistroGuardado(BuildContext context) => showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final tema = Theme.of(context).textTheme;
        return AlertDialog(
          backgroundColor: colorFondo,
          title: const Text('Registro guardado'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('La información se guardó correctamente.', style: tema.bodySmall?.copyWith(color: colorTextoSuave)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: colorVerdeSuave, borderRadius: BorderRadius.circular(10)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      Granjas.instance.actual.nombre,
                      style: tema.labelLarge?.copyWith(color: colorVerdeOscuro, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text('Se conservan las relaciones y la autoría.', style: tema.bodySmall?.copyWith(color: colorTextoSuave)),
                  ],
                ),
              ),
            ],
          ),
          actions: [BotonPrincipal(texto: 'Continuar', alPresionar: () => Navigator.pop(context))],
        );
      },
    );
