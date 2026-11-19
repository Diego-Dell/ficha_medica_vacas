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
      OpcionPanel(titulo: 'Clínica', detalle: 'Registrar atención médica.', alPresionar: null),
      OpcionPanel(titulo: 'Reproducción', detalle: 'Valorar aptitud y preñez; registrar parto o pérdida.', alPresionar: null),
      OpcionPanel(titulo: 'Tratamiento', detalle: 'Registrar la prescripción de una atención médica.', alPresionar: null),
      OpcionPanel(titulo: 'Prevención', detalle: 'Programar vacunas, desparasitación y controles.', alPresionar: null),
      OpcionPanel(titulo: 'Consulta', detalle: 'Buscar animales y revisar su seguimiento.', alPresionar: null),
    ],
  );
}
