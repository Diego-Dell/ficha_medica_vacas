import 'package:flutter/material.dart';

import '../../widgets/campos_granja.dart';
import '../../widgets/panel_rol.dart';

class CuidadosHoyScreen extends StatelessWidget {
  const CuidadosHoyScreen({
    super.key,
    required this.granja,
    this.alCerrarSesion,
  });
  final String granja;
  final VoidCallback? alCerrarSesion;

  @override
  Widget build(BuildContext context) => PanelRol(
    rol: 'Trabajador',
    granja: granja,
    alCerrarSesion: alCerrarSesion,
    children: [
      AvisoRol(
        titulo: 'Acceso como trabajador',
        texto: 'Tu cuenta está vinculada a $granja con el rol que te asignó el dueño. '
            'Si trabajás en otras granjas, elegilas en Mis granjas.',
      ),
    ],
  );
}
