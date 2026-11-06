import 'package:flutter/material.dart';

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
    children: const [
      OpcionPanel(
        titulo: 'Clínica',
        detalle: 'Registrar diagnóstico, control o evolución.',
      ),
      OpcionPanel(
        titulo: 'Reproducción',
        detalle: 'Valorar aptitud y preñez; registrar parto o pérdida.',
      ),
      OpcionPanel(
        titulo: 'Tratamiento',
        detalle: 'Registrar la prescripción y el retiro.',
      ),
      OpcionPanel(
        titulo: 'Prevención',
        detalle: 'Programar vacunas, desparasitación y controles.',
      ),
      OpcionPanel(
        titulo: 'Consulta',
        detalle: 'Buscar animales y revisar su seguimiento.',
      ),
    ],
  );
}
