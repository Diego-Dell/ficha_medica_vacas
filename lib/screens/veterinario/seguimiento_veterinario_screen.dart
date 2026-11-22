import 'package:flutter/material.dart';

import '../../widgets/panel_rol.dart';
import 'registro_clinico_screen.dart';

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
    children: [
      const TituloGrupo('Registrar'),
      // 2. Se activan con los módulos de Clínica y Tratamientos.
      Accesos(children: [
        Acceso(titulo: 'Clínica', icono: 'clinica', alPresionar: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegistroClinicoScreen()))),
        Acceso(titulo: 'Reproducción', icono: 'reproduccion', alPresionar: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegistroClinicoScreen(reproductivo: true)))),
        const Acceso(titulo: 'Tratamiento', icono: 'tratamiento', alPresionar: null),
        const Acceso(titulo: 'Prevención', icono: 'vacuna', alPresionar: null),
      ]),
    ],
  );
}
