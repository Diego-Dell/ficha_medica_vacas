import 'package:flutter/material.dart';

import '../../widgets/panel_rol.dart';

// 1. Inicio del trabajador; fichas y consulta están en la pestaña Ganado.
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
        children: const [
          TituloGrupo('Registrar'),
          // 2. Se activan con el módulo de Cuidados y aplicaciones.
          Accesos(children: [
            Acceso(titulo: 'Observación', icono: 'cuidado', alPresionar: null),
            Acceso(titulo: 'Aplicación', icono: 'medicamento', alPresionar: null),
          ]),
        ],
      );
}
