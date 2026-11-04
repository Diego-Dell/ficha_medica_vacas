import 'package:flutter/material.dart';

import '../logic/sesion.dart';
import '../widgets/vetlink.dart';

class CrearCuentaScreen extends StatefulWidget {
  const CrearCuentaScreen({super.key});

  @override
  State<CrearCuentaScreen> createState() => _CrearCuentaScreenState();
}

class _CrearCuentaScreenState extends State<CrearCuentaScreen> {
  final _form = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _correo = TextEditingController();
  final _contrasena = TextEditingController();
  bool _enviando = false;

  @override
  void dispose() {
    for (final c in [_nombre, _correo, _contrasena]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _contrasenaValida(String? valor) => (valor ?? '').length < 6 ? 'Mínimo 6 caracteres' : null;

  Future<void> _enviar() async {
    // 1. Valida el formulario y evita envíos dobles.
    if (_enviando || !_form.currentState!.validate()) return;
    setState(() => _enviando = true);

    // 2. Crea la cuenta sin granja propia.
    final error = await Sesion.instance.crearCuentaInvitada(_nombre.text, _correo.text, _contrasena.text);
    if (!mounted) return;
    setState(() => _enviando = false);

    // 3. Muestra el error o explica el siguiente paso y vuelve al login.
    if (error != null) {
      avisar(context, error);
      return;
    }
    avisar(context, 'Confirma tu correo e inicia sesión para aceptar la invitación');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return PantallaVetLink(
      titulo: 'Crear cuenta',
      subtitulo: 'Usa el mismo correo en el que recibiste la invitación.',
      children: [
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CampoEtiquetado(
                etiqueta: 'Nombre completo *',
                child: TextFormField(
                  controller: _nombre,
                  decoration: decoracionCampo(pista: 'Sofía Rojas'),
                  textCapitalization: TextCapitalization.words,
                  validator: requerido,
                ),
              ),
              CampoEtiquetado(
                etiqueta: 'Correo electrónico *',
                child: TextFormField(
                  controller: _correo,
                  decoration: decoracionCampo(pista: 'sofia@ejemplo.com'),
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  validator: requerido,
                ),
              ),
              CampoEtiquetado(
                etiqueta: 'Contraseña *',
                child: TextFormField(
                  controller: _contrasena,
                  decoration: decoracionCampo(),
                  obscureText: true,
                  validator: _contrasenaValida,
                ),
              ),
            ],
          ),
        ),
        BotonPrincipal(texto: _enviando ? 'Creando...' : 'Crear cuenta', alPresionar: _enviando ? null : _enviar),
        BotonSecundario(texto: 'Volver', alPresionar: () => Navigator.pop(context)),
      ],
    );
  }
}
