import 'package:flutter/material.dart';

import '../../widgets/campos_granja.dart';
import '../ganado/ganado_screen.dart';
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
      OpcionPanel(
        titulo: 'Ganado',
        detalle: 'Registrar o actualizar los datos generales de los animales.',
        alPresionar: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GanadoScreen())),
      ),
      AvisoRol(
        titulo: 'Acceso como trabajador',
        texto: 'Tu cuenta está vinculada a $granja con el rol que te asignó el dueño. '
            'Si trabajás en otras granjas, elegilas en Mis granjas.',
      ),
    ],
  );
}
