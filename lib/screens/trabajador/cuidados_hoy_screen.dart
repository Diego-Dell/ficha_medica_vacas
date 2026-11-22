import 'package:flutter/material.dart';

import '../../widgets/panel_rol.dart';
import '../ganado/editar_ficha_screen.dart';
import '../ganado/ganado_screen.dart';

class CuidadosHoyScreen extends StatelessWidget {
  const CuidadosHoyScreen({
    super.key,
    required this.granja,
    this.alCerrarSesion,
  });
  final String granja;
  final VoidCallback? alCerrarSesion;

  @override
  Widget build(BuildContext context) {
    void abrir(Widget pantalla) => Navigator.push(context, MaterialPageRoute(builder: (_) => pantalla));
    return PanelRol(
      rol: 'Trabajador',
      granja: granja,
      alCerrarSesion: alCerrarSesion,
      mostrarReportes: false,
      children: [
        OpcionPanel(
          titulo: 'Ficha',
          detalle: 'Registrar o actualizar los datos del animal.',
          alPresionar: () => abrir(const EditarFichaScreen()),
        ),
        const OpcionPanel(titulo: 'Observación', detalle: 'Describir lo observado y el cuidado realizado.', alPresionar: null),
        const OpcionPanel(titulo: 'Aplicación', detalle: 'Registrar la aplicación de una indicación.', alPresionar: null),
        OpcionPanel(
          titulo: 'Consulta',
          detalle: 'Buscar animales y consultar su seguimiento.',
          alPresionar: () => abrir(const GanadoScreen()),
        ),
      ],
    );
  }
}
