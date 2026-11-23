import 'package:flutter/material.dart';

import '../../logic/granjas.dart';
import '../../widgets/vetlink.dart';

// 1. Ventana "Registro guardado".
Future<void> mostrarRegistroGuardado(BuildContext context) => showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => VentanaVetLink(
        icono: 'check',
        titulo: 'Registro guardado',
        texto: 'La información de ${Granjas.instance.actual.nombre} se guardó correctamente.',
        acciones: [BotonPrincipal(texto: 'Continuar', alPresionar: () => Navigator.pop(context))],
      ),
    );
