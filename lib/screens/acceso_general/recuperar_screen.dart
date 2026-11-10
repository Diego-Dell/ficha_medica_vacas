import 'package:flutter/material.dart';

import '../../logic/sesion.dart';
import '../../widgets/vetlink.dart';
import '../../widgets/pantalla.dart';

class RecuperarScreen extends StatefulWidget {
  const RecuperarScreen({super.key});

  @override
  State<RecuperarScreen> createState() => _RecuperarScreenState();
}

class _RecuperarScreenState extends State<RecuperarScreen> {
  final _form = GlobalKey<FormState>();
  final _correo = TextEditingController();
  bool _enviando = false;

  @override
  void dispose() {
    _correo.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    // 1. Valida el formulario y evita envíos dobles.
    if (_enviando || !_form.currentState!.validate()) return;
    setState(() => _enviando = true);

    // 2. Pide al servidor enviar el enlace con Mailgun.
    final error = await Sesion.instance.recuperar(_correo.text);
    if (!mounted) return;
    setState(() => _enviando = false);

    // 3. Muestra el resultado sin revelar si el correo tiene cuenta.
    avisar(context, error ?? 'Si el correo tiene una cuenta, te enviamos el enlace');
  }

  @override
  Widget build(BuildContext context) {
    return Pantalla(
      titulo: 'Recuperar contraseña',
      subtitulo: 'Te enviaremos un correo para recuperar el acceso.',
      children: [
        Form(
          key: _form,
          child: CampoEtiquetado(
            etiqueta: 'Correo electrónico',
            child: TextFormField(
              controller: _correo,
              decoration: decoracionCampo(pista: 'ana@ejemplo.com'),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              autocorrect: false,
              onFieldSubmitted: (_) => _enviar(),
              validator: requerido,
            ),
          ),
        ),
        const Text(
          'Si no lo encontrás, revisá la carpeta de correo no deseado.',
          style: TextStyle(color: colorTextoSuave, fontSize: 12),
        ),
        const SizedBox(height: 24),
        BotonPrincipal(texto: _enviando ? 'Enviando...' : 'Enviar enlace', alPresionar: _enviando ? null : _enviar),
      ],
    );
  }
}
