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
  bool _enviando = false;

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

  Future<void> _enviar() async {
    // 1. Valida el formulario y evita envíos dobles.
    if (_enviando || !_form.currentState!.validate()) return;
    setState(() => _enviando = true);

    // 2. Guarda la invitación y envía el correo.
    final resultado = await Granjas.instance.invitar(_correo.text, _rol);
    if (!mounted) return;
    setState(() => _enviando = false);

    // 3. Muestra el error o avisa el resultado y vuelve a Miembros.
    final error = resultado.error;
    if (error != null) {
      avisar(context, error);
      return;
    }
    avisar(
      context,
      resultado.correoEnviado
          ? 'Invitación enviada a ${_correo.text.trim().toLowerCase()}'
          : 'La invitación quedó guardada, pero no se pudo enviar el correo. Reenvíala desde Miembros',
    );
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
          texto: 'Recibirá un correo con los pasos. Si ya tiene cuenta, podrá aceptarla con esa misma cuenta. No se envían códigos.',
        ),
        BotonPrincipal(texto: _enviando ? 'Enviando...' : 'Enviar invitación', alPresionar: _enviando ? null : _enviar),
        BotonSecundario(texto: 'Volver', alPresionar: volver),
      ],
    );
  }
}
