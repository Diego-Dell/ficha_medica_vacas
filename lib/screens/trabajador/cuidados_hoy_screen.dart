import 'package:flutter/material.dart';

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
    children: const [
      OpcionPanel(
        titulo: 'Ficha',
        detalle: 'Registrar o actualizar los datos del animal.',
      ),
      OpcionPanel(
        titulo: 'Observación',
        detalle: 'Describir lo observado y el cuidado realizado.',
      ),
      OpcionPanel(
        titulo: 'Aplicación',
        detalle: 'Registrar la aplicación de una indicación.',
      ),
      OpcionPanel(
        titulo: 'Consulta',
        detalle: 'Buscar animales y consultar su seguimiento.',
      ),
    ],
  );
}
