import 'package:flutter/material.dart';

import '../../widgets/panel_rol.dart';
import '../../widgets/vetlink.dart';

class AdministracionScreen extends StatelessWidget {
  const AdministracionScreen({
    super.key,
    required this.granja,
    this.pendientes = 0,
    this.alCerrarSesion,
  });
  final String granja;
  final int? pendientes;
  final VoidCallback? alCerrarSesion;

  @override
  Widget build(BuildContext context) => PanelRol(
    titulo: 'Administración',
    subtitulo: 'Gestión general del sistema.',
    rol: 'Administrador',
    granja: granja,
    alCerrarSesion: alCerrarSesion,
    children: [
      Container(
        padding: const EdgeInsets.all(13),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: colorVerdeSuave,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              pendientes == null
                  ? 'Solicitudes de granjas'
                  : '$pendientes ${pendientes == 1 ? 'granja' : 'granjas'} por confirmar',
              style: const TextStyle(
                color: colorVerdeOscuro,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              pendientes == null
                  ? 'La consulta de solicitudes todavía no está disponible.'
                  : pendientes! > 0
                  ? 'Solicitud recibida: $granja.'
                  : 'No hay solicitudes pendientes.',
              style: const TextStyle(color: colorTextoSuave, fontSize: 12),
            ),
          ],
        ),
      ),
      const OpcionPanel(
        compacta: true,
        titulo: 'Cuentas y accesos',
        detalle: 'Corregir datos, recuperar o desactivar accesos.',
      ),
      const OpcionPanel(
        compacta: true,
        titulo: 'Confirmar granjas',
        detalle: 'Revisar datos y documentación.',
      ),
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          'OPERACIONES EN ${granja.toUpperCase()}',
          style: const TextStyle(color: colorTextoSuave, fontSize: 11),
        ),
      ),
      const OpcionPanel(
        compacta: true,
        titulo: 'Ganado e historial',
        detalle: 'Consulta de fichas y antecedentes.',
      ),
      const OpcionPanel(
        compacta: true,
        titulo: 'Datos y bajas',
        detalle: 'Gestión de fichas del ganado.',
      ),
      const OpcionPanel(
        compacta: true,
        titulo: 'Atenciones y cuidados',
        detalle: 'Operaciones clínicas y de seguimiento habilitadas.',
      ),
    ],
  );
}
