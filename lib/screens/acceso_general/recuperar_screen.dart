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
  bool _enviado = false;

  @override
  void dispose() {
    _correo.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    // 1. Valida el formulario y evita envíos dobles.
    if (_enviando || !_form.currentState!.validate()) return;
    setState(() => _enviando = true);

    // 2. Pide a Supabase enviar el enlace.
    final error = await Sesion.instance.recuperar(_correo.text);
    if (!mounted) return;
    setState(() => _enviando = false);

    // 3. Muestra el resultado sin revelar si el correo tiene cuenta.
    avisar(context, error ?? 'Si el correo tiene una cuenta, te enviamos el enlace');
    if (error == null) setState(() => _enviado = true);
  }

  @override
  Widget build(BuildContext context) {
    // 4. Después de enviar, "Revisá tu correo".
    if (_enviado) {
      return Pantalla(
        titulo: 'Revisá tu correo',
        children: [
          const SizedBox(height: 40),
          const Center(child: BurbujaIcono('correo', tam: 88)),
          const SizedBox(height: 16),
          Text('Te enviamos un enlace', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'Abrí el correo de ${_correo.text.trim()} desde este celular para crear una nueva contraseña. Si no lo ves, revisá la carpeta de spam.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colorTextoSuave),
          ),
          const SizedBox(height: 32),
          BotonSecundario(texto: 'Volver al login', alPresionar: () => Navigator.pop(context)),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: colorVerde),
            onPressed: () => setState(() => _enviado = false),
            child: const Text('Reenviar correo'),
          ),
        ],
      );
    }
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
              decoration: decoracionCampo(pista: 'ana@ejemplo.com', icono: 'correo'),
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
