import 'package:flutter/material.dart';

import '../logic/sesion.dart';
import '../models/granja.dart';
import '../widgets/campos_granja.dart';
import '../widgets/vetlink.dart';
import 'granja_revision_screen.dart';

class RegistrarGranjaScreen extends StatefulWidget {
  const RegistrarGranjaScreen({super.key, this.elegir = elegirDocumento});

  final Future<String?> Function() elegir;

  @override
  State<RegistrarGranjaScreen> createState() => _RegistrarGranjaScreenState();
}

class _RegistrarGranjaScreenState extends State<RegistrarGranjaScreen> {
  final _form = GlobalKey<FormState>();
  final _dueno = TextEditingController();
  final _correo = TextEditingController();
  final _contrasena = TextEditingController();
  final _granja = TextEditingController();
  final _superficie = TextEditingController();
  final _runsa = TextEditingController();
  String? _documento;
  bool _enviando = false;

  @override
  void dispose() {
    for (final c in [_dueno, _correo, _contrasena, _granja, _superficie, _runsa]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _contrasenaValida(String? valor) => (valor ?? '').length < 6 ? 'Mínimo 6 caracteres' : null;

  Future<void> _enviar() async {
    // 1. Valida el formulario y evita envíos dobles.
    if (_enviando || !_form.currentState!.validate()) return;
    setState(() => _enviando = true);

    // 2. Crea la cuenta con los datos de la granja.
    final granja = Granja(
      nombre: _granja.text.trim(),
      dueno: _dueno.text.trim(),
      superficie: leerSuperficie(_superficie.text),
      runsa: _runsa.text.trim(),
      documento: _documento!,
    );
    final error = await Sesion.instance.registrar(_correo.text, _contrasena.text, granja);
    if (!mounted) return;
    setState(() => _enviando = false);

    // 3. Muestra el error o pasa a Granja en revisión.
    if (error != null) {
      avisar(context, error);
      return;
    }
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => GranjaRevisionScreen(granja: granja)));
  }

  @override
  Widget build(BuildContext context) {
    final seccion = Theme.of(context).textTheme.labelSmall?.copyWith(color: colorTextoSuave);
    return PantallaVetLink(
      titulo: 'Registrar mi granja',
      subtitulo: 'Creá tu cuenta y registrá tu granja.',
      children: [
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('1 · TUS DATOS', style: seccion)),
              CampoEtiquetado(
                etiqueta: 'Nombre completo *',
                child: TextFormField(
                  controller: _dueno,
                  decoration: decoracionCampo(pista: 'Ana Pérez'),
                  textCapitalization: TextCapitalization.words,
                  validator: requerido,
                ),
              ),
              CampoEtiquetado(
                etiqueta: 'Correo electrónico *',
                child: TextFormField(
                  controller: _correo,
                  decoration: decoracionCampo(pista: 'ana@ejemplo.com'),
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
              Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('2 · TU GRANJA', style: seccion)),
              CamposGranja(
                nombre: _granja,
                superficie: _superficie,
                runsa: _runsa,
                elegir: widget.elegir,
                alElegirDocumento: (archivo) => _documento = archivo,
              ),
            ],
          ),
        ),
        const AvisoRol(
          titulo: 'Tu rol será Dueño',
          texto: 'Podrás invitar a tu equipo cuando se confirme la granja.',
        ),
        BotonPrincipal(texto: _enviando ? 'Enviando...' : 'Enviar registro', alPresionar: _enviando ? null : _enviar),
        BotonSecundario(texto: 'Volver', alPresionar: () => Navigator.pop(context)),
      ],
    );
  }
}
