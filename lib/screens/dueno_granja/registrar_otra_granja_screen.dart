import 'package:flutter/material.dart';

import '../../logic/granjas.dart';
import '../../logic/sesion.dart';
import '../../models/granja.dart';
import '../../widgets/campos_granja.dart';
import '../../widgets/vetlink.dart';

class RegistrarOtraGranjaScreen extends StatefulWidget {
  const RegistrarOtraGranjaScreen({super.key, this.elegir = elegirDocumento});

  final Future<String?> Function() elegir;

  @override
  State<RegistrarOtraGranjaScreen> createState() => _RegistrarOtraGranjaScreenState();
}

class _RegistrarOtraGranjaScreenState extends State<RegistrarOtraGranjaScreen> {
  final _form = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _superficie = TextEditingController();
  final _runsa = TextEditingController();
  String? _documento;
  bool _enviando = false;

  @override
  void dispose() {
    for (final c in [_nombre, _superficie, _runsa]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _enviar() async {
    // 1. Valida el formulario y evita envíos dobles.
    if (_enviando || !_form.currentState!.validate()) return;
    setState(() => _enviando = true);

    // 2. Guarda el registro con la cuenta actual.
    final granja = Granja(
      nombre: _nombre.text.trim(),
      dueno: Sesion.instance.nombre,
      superficie: leerSuperficie(_superficie.text),
      runsa: _runsa.text.trim(),
      documento: _documento!,
    );
    final error = await Granjas.instance.registrarGranja(granja);
    if (!mounted) return;
    setState(() => _enviando = false);

    // 3. Muestra el error o avisa el resultado y vuelve a Mi granja.
    if (error != null) {
      avisar(context, error);
      return;
    }
    avisar(context, 'Recibimos el registro de ${granja.nombre}. Queda en revisión');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    void volver() => Navigator.pop(context);
    return PantallaVetLink(
      encabezado: EncabezadoVetLink(granja: Granjas.instance.actual.nombre, rol: 'Dueño', alVolver: volver),
      barraInferior: BarraVetLink(alVolver: volver),
      titulo: 'Registrar otra granja',
      subtitulo: 'Se usará tu cuenta actual: ${Sesion.instance.usuario ?? ''}.',
      children: [
        Form(
          key: _form,
          child: CamposGranja(
            nombre: _nombre,
            superficie: _superficie,
            runsa: _runsa,
            elegir: widget.elegir,
            alElegirDocumento: (archivo) => _documento = archivo,
            etiquetaNombre: 'Nombre de la granja *',
            etiquetaDocumento: 'Documentación *',
          ),
        ),
        const AvisoRol(
          titulo: 'Serás dueño de esta nueva granja',
          texto: 'Tus roles en las otras granjas se mantienen.',
        ),
        BotonPrincipal(texto: _enviando ? 'Enviando...' : 'Enviar registro', alPresionar: _enviando ? null : _enviar),
        BotonSecundario(texto: 'Volver', alPresionar: volver),
      ],
    );
  }
}
