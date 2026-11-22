import 'package:flutter/material.dart';

import '../../logic/granjas.dart';
import '../../models/miembro.dart';
import '../../widgets/panel_rol.dart';
import '../ganado/editar_ficha_screen.dart';
import '../ganado/ganado_screen.dart';
import 'miembros_screen.dart';
import 'registrar_otra_granja_screen.dart';

class MiGranjaScreen extends StatelessWidget {
  const MiGranjaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final datos = Granjas.instance;
    final esDueno = datos.rol == RolMiembro.dueno;
    void abrir(Widget pantalla) => Navigator.push(context, MaterialPageRoute(builder: (_) => pantalla));
    return PanelRol(
      rol: datos.rol.etiqueta,
      granja: datos.actual.nombre,
      alRegistrarGranja: esDueno ? () => abrir(const RegistrarOtraGranjaScreen()) : null,
      mostrarReportes: datos.rol != RolMiembro.trabajador,
      children: [
        OpcionPanel(
          titulo: 'Ficha',
          detalle: 'Crear o actualizar los datos del ganado.',
          alPresionar: () => abrir(const EditarFichaScreen()),
        ),
        // 1. La baja se registra desde la ficha del animal elegido en la lista.
        OpcionPanel(
          titulo: 'Baja del animal',
          detalle: 'Registrar fecha y motivo; conservar el historial.',
          alPresionar: () => abrir(const GanadoScreen()),
        ),
        OpcionPanel(
          titulo: 'Búsqueda',
          detalle: 'Buscar animales, revisar antecedentes y avisos.',
          alPresionar: () => abrir(const GanadoScreen()),
        ),
        if (esDueno)
          OpcionPanel(
            titulo: 'Gestionar miembros',
            detalle: 'Invitar personas y administrar el equipo.',
            alPresionar: () => abrir(const MiembrosScreen()),
          ),
      ],
    );
  }
}
