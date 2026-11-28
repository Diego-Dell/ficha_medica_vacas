import 'package:flutter/material.dart';

import '../../widgets/panel_rol.dart';
import 'registro_clinico_screen.dart';
import 'tratamiento_screen.dart';
import 'prevencion_screen.dart';

// 1. Inicio del veterinario; Consulta y Reportes viven en la barra inferior.
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
      const TituloGrupo('Gestionar seguimiento veterinario'),
      // 2. Módulos clínicos y preventivos en grilla 2x2 como en el diseño.
      Accesos(children: [
        Acceso(titulo: 'Clínica', icono: 'clinica', alPresionar: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegistroClinicoScreen()))),
        Acceso(titulo: 'Reproducción', icono: 'reproduccion', alPresionar: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegistroClinicoScreen(reproductivo: true)))),
        Acceso(titulo: 'Tratamiento', icono: 'tratamiento', alPresionar: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TratamientoScreen()))),
        Acceso(titulo: 'Prevención', icono: 'vacuna', alPresionar: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrevencionScreen()))),
      ]),
    ],
  );
}
