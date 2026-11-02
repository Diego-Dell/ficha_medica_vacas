import 'package:flutter/material.dart';

import '../logic/sesion.dart';
import '../widgets/vetlink.dart';

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
    if (_enviando || !_form.currentState!.validate()) return;
    setState(() => _enviando = true);
    final error = await Sesion.instance.recuperar(_correo.text);
    if (!mounted) return;
    setState(() => _enviando = false);
    avisar(context, error ?? 'Si el correo tiene una cuenta, te enviamos el enlace');
  }

  @override
  Widget build(BuildContext context) {
    return PantallaVetLink(
      titulo: 'Recuperar acceso',
      subtitulo: 'Te enviaremos un enlace al correo de tu cuenta.',
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
        BotonPrincipal(texto: _enviando ? 'Enviando...' : 'Enviar enlace', alPresionar: _enviando ? null : _enviar),
        BotonSecundario(texto: 'Volver', alPresionar: () => Navigator.pop(context)),
      ],
    );
  }
}
