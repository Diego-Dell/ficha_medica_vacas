import 'package:flutter/material.dart';

import '../../widgets/panel_rol.dart';

// 1. Inicio del veterinario; Consulta está en la pestaña Ganado.
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
        children: const [
          TituloGrupo('Registrar'),
          // 2. Se activan con los módulos de Clínica y Tratamientos.
          Accesos(children: [
            Acceso(titulo: 'Clínica', icono: 'clinica', alPresionar: null),
            Acceso(titulo: 'Reproducción', icono: 'reproduccion', alPresionar: null),
            Acceso(titulo: 'Tratamiento', icono: 'tratamiento', alPresionar: null),
            Acceso(titulo: 'Prevención', icono: 'vacuna', alPresionar: null),
          ]),
        ],
      );
}
