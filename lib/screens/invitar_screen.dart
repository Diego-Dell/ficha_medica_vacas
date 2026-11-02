import 'package:flutter/material.dart';

import '../logic/granjas.dart';
import '../models/miembro.dart';
import '../widgets/campos_granja.dart';
import '../widgets/vetlink.dart';

class InvitarScreen extends StatefulWidget {
  const InvitarScreen({super.key});

  @override
  State<InvitarScreen> createState() => _InvitarScreenState();
}

class _InvitarScreenState extends State<InvitarScreen> {
  final _form = GlobalKey<FormState>();
  final _correo = TextEditingController();
  RolMiembro _rol = RolMiembro.veterinario;

  @override
  void dispose() {
    _correo.dispose();
    super.dispose();
  }

  String? _correoValido(String? valor) {
    final correo = (valor ?? '').trim();
    if (correo.isEmpty) return 'Campo obligatorio';
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(correo) ? null : 'Correo no válido';
  }

  void _enviar() {
    // 1. Valida el formulario.
    if (!_form.currentState!.validate()) return;

    // 2. Registra la invitación pendiente.
    final error = Granjas.instance.invitar(_correo.text, _rol);

    // 3. Muestra el error o vuelve a Miembros.
    if (error != null) {
      avisar(context, error);
      return;
    }
    avisar(context, 'Invitación registrada. El envío por correo aún no está disponible');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final granja = Granjas.instance.actual.nombre;
    void volver() => Navigator.pop(context);

    return PantallaVetLink(
      encabezado: EncabezadoVetLink(granja: granja, alVolver: volver),
      barraInferior: BarraVetLink(alVolver: volver),
      titulo: 'Invitar al equipo',
      subtitulo: 'Elegí el correo y el rol de la persona.',
      children: [
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CampoEtiquetado(
                etiqueta: 'Correo electrónico *',
                child: TextFormField(
                  controller: _correo,
                  decoration: decoracionCampo(pista: 'sofia@ejemplo.com'),
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  validator: _correoValido,
                ),
              ),
              CampoEtiquetado(
                etiqueta: 'Rol en $granja *',
                child: DropdownButtonFormField<RolMiembro>(
                  initialValue: _rol,
                  decoration: decoracionCampo(),
                  items: [
                    for (final rol in [RolMiembro.veterinario, RolMiembro.trabajador])
                      DropdownMenuItem(value: rol, child: Text(rol.etiqueta)),
                  ],
                  onChanged: (rol) => setState(() => _rol = rol ?? _rol),
                ),
              ),
            ],
          ),
        ),
        const AvisoRol(
          titulo: 'Una invitación por correo',
          texto: 'Recibirá un enlace. Si ya tiene cuenta, podrá aceptarla con esa misma cuenta. No se envían códigos.',
        ),
        BotonPrincipal(texto: 'Enviar invitación', alPresionar: _enviar),
        BotonSecundario(texto: 'Volver', alPresionar: volver),
      ],
    );
  }
}
