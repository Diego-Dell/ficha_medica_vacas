import 'package:flutter/material.dart';

import '../../logic/granjas.dart';
import '../../models/miembro.dart';
import '../../widgets/campos_granja.dart';
import '../../widgets/vetlink.dart';

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
    // 5. Con el correo enviado muestra la ventana "Invitación enviada".
    final correo = _correo.text.trim().toLowerCase();
    if (resultado.errorCorreo == null) {
      await showDialog<void>(
        context: context,
        builder: (context) => VentanaVetLink(
          icono: 'correo',
          titulo: 'Invitación enviada',
          texto: '$correo recibirá un correo para unirse como ${_rol.etiqueta}.',
          acciones: [BotonPrincipal(texto: 'Listo', alPresionar: () => Navigator.pop(context))],
        ),
      );
    } else {
      avisar(
        context,
        'La invitación quedó guardada, pero el correo no salió: ${resultado.errorCorreo}. Reenvíala desde Miembros',
      );
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final granja = Granjas.instance.actual.nombre;
    void volver() => Navigator.pop(context);

    return PantallaVetLink(
      encabezado: EncabezadoVetLink(granja: granja, alVolver: volver),
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
                  decoration: decoracionCampo(pista: 'sofia@ejemplo.com', icono: 'correo'),
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  validator: _correoValido,
                ),
              ),
              CampoEtiquetado(
                etiqueta: 'Rol en $granja *',
                // 4. Rol como dos opciones visibles.
                child: Row(
                  children: [
                    for (final rol in [RolMiembro.veterinario, RolMiembro.trabajador])
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(right: rol == RolMiembro.veterinario ? 8 : 0),
                          child: Material(
                            color: _rol == rol ? colorVerdeSuave : colorSuperficie,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(radioCampo),
                              side: BorderSide(
                                color: _rol == rol ? colorVerde : colorBorde,
                                width: _rol == rol ? 1.5 : 1,
                              ),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(radioCampo),
                              onTap: () => setState(() => _rol = rol),
                              child: SizedBox(
                                height: 52,
                                child: Center(
                                  child: Text(
                                    rol.etiqueta,
                                    style: TextStyle(
                                      fontWeight: _rol == rol ? FontWeight.w600 : FontWeight.w400,
                                      color: _rol == rol ? colorVerde : colorTextoSuave,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
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
      ],
    );
  }
}
