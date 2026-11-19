import 'package:flutter/material.dart';

import '../../logic/granjas.dart';
import '../../models/miembro.dart';
import '../../widgets/panel_rol.dart';
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
        const OpcionPanel(titulo: 'Ficha', detalle: 'Crear o actualizar los datos del ganado.', alPresionar: null),
        const OpcionPanel(titulo: 'Baja del animal', detalle: 'Registrar fecha y motivo; conservar el historial.', alPresionar: null),
        const OpcionPanel(titulo: 'Búsqueda', detalle: 'Buscar animales, revisar antecedentes y avisos.', alPresionar: null),
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
