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
    mostrarReportes: false,
    children: const [
      OpcionPanel(titulo: 'Ficha', detalle: 'Registrar o actualizar los datos del animal.', alPresionar: null),
      OpcionPanel(titulo: 'Observación', detalle: 'Describir lo observado y el cuidado realizado.', alPresionar: null),
      OpcionPanel(titulo: 'Aplicación', detalle: 'Registrar la aplicación de una indicación.', alPresionar: null),
      OpcionPanel(titulo: 'Consulta', detalle: 'Buscar animales y consultar su seguimiento.', alPresionar: null),
    ],
  );
}
