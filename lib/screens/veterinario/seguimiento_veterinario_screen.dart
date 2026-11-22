import 'package:flutter/material.dart';

import '../../widgets/panel_rol.dart';
import '../ganado/ganado_screen.dart';

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
      const OpcionPanel(titulo: 'Clínica', detalle: 'Registrar atención médica.', alPresionar: null),
      const OpcionPanel(titulo: 'Reproducción', detalle: 'Valorar aptitud y preñez; registrar parto o pérdida.', alPresionar: null),
      const OpcionPanel(titulo: 'Tratamiento', detalle: 'Registrar la prescripción de una atención médica.', alPresionar: null),
      const OpcionPanel(titulo: 'Prevención', detalle: 'Programar vacunas, desparasitación y controles.', alPresionar: null),
      OpcionPanel(
        titulo: 'Consulta',
        detalle: 'Buscar animales y revisar su seguimiento.',
        alPresionar: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GanadoScreen())),
      ),
    ],
  );
}
