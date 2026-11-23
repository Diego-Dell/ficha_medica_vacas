import 'package:flutter/material.dart';

import '../../models/miembro.dart';
import '../../widgets/campos_granja.dart';
import '../../widgets/vetlink.dart';

/// Confirma la invitación de la cuenta que ya inició sesión; el login conserva la aceptación y el acceso por rol.
class AceptarInvitacionScreen extends StatelessWidget {
  const AceptarInvitacionScreen({super.key, required this.invitacion});

  final Invitacion invitacion;

  @override
  Widget build(BuildContext context) => PantallaVetLink(
    encabezado: EncabezadoVetLink(
      alVolver: () => Navigator.pop(context, false),
    ),
    titulo: 'Aceptar invitación',
    subtitulo:
        '${invitacion.granjaNombre ?? 'Invitación a una granja'} · ${invitacion.rol.etiqueta}',
    children: [
      AvisoRol(
        titulo: 'Rol asignado: ${invitacion.rol.etiqueta}',
        texto: 'Este rol lo asignó el dueño de la granja.',
      ),
      CampoEtiquetado(
        etiqueta: 'Correo invitado',
        child: TextFormField(
          initialValue: invitacion.correo,
          readOnly: true,
          decoration: decoracionCampo(),
        ),
      ),
      const AvisoRol(
        titulo: 'Se usará tu cuenta actual',
        texto: 'Se agregará esta granja a tu cuenta. Tus otras vinculaciones se mantienen.',
      ),
      BotonPrincipal(
        texto: 'Aceptar invitación',
        alPresionar: () => Navigator.pop(context, true),
      ),
      BotonSecundario(
        texto: 'Ahora no',
        alPresionar: () => Navigator.pop(context, false),
      ),
      const SizedBox(height: 8),
      const Text(
        'No necesitás introducir ningún código.',
        style: TextStyle(color: colorTextoSuave, fontSize: 12),
      ),
    ],
  );
}
