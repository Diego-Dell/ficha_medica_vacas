import 'package:flutter/material.dart';

import '../../widgets/campos_granja.dart';
import '../../widgets/panel_rol.dart';

class SeguimientoVeterinarioScreen extends StatelessWidget {
  const SeguimientoVeterinarioScreen({
    super.key,
    required this.granja,
    this.alCerrarSesion,
  });
  final String granja;
  final VoidCallback? alCerrarSesion;

  @override
  Widget build(BuildContext context) => PanelRol(
    rol: 'Veterinario',
    granja: granja,
    alCerrarSesion: alCerrarSesion,
    children: [
      AvisoRol(
        titulo: 'Acceso como veterinario',
        texto: 'Tu cuenta está vinculada a $granja con el rol que te asignó el dueño. '
            'Si atendés otras granjas, elegilas en Mis granjas.',
      ),
    ],
  );
}
