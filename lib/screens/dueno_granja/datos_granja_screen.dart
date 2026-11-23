import 'package:flutter/material.dart';

import '../../logic/granjas.dart';
import '../../widgets/vetlink.dart';

// 1. Datos de la granja: el dueño actualiza el RUNSA.
class DatosGranjaScreen extends StatefulWidget {
  const DatosGranjaScreen({super.key});

  @override
  State<DatosGranjaScreen> createState() => _DatosGranjaScreenState();
}

class _DatosGranjaScreenState extends State<DatosGranjaScreen> {
  final _form = GlobalKey<FormState>();
  late final _runsa = TextEditingController(text: Granjas.instance.actual.runsa);
  bool _enviando = false;

  @override
  void dispose() {
    _runsa.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    // 2. Valida y evita envíos dobles.
    if (_enviando || !_form.currentState!.validate()) return;
    setState(() => _enviando = true);
    final error = await Granjas.instance.actualizarRunsa(_runsa.text);
    if (!mounted) return;
    setState(() => _enviando = false);

    // 3. Avisa el resultado y vuelve al inicio con el dato nuevo.
    avisar(context, error ?? 'RUNSA actualizado');
    if (error == null) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final granja = Granjas.instance.actual;
    final tema = Theme.of(context).textTheme;
    Widget dato(String etiqueta, String valor) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Text(etiqueta, style: tema.bodySmall),
          const Spacer(),
          Text(
            valor,
            style: const TextStyle(fontWeight: FontWeight.w600, color: colorVerdeOscuro),
          ),
        ],
      ),
    );

    return PantallaVetLink(
      encabezado: EncabezadoVetLink(granja: granja.nombre, alVolver: () => Navigator.pop(context)),
      titulo: 'Datos de la granja',
      children: [
        Tarjeta(
          child: Column(
            children: [
              dato('Nombre', granja.nombre),
              dato('Superficie', '${granja.superficie.toStringAsFixed(granja.superficie % 1 == 0 ? 0 : 2)} ha'),
              dato('Estado', granja.confirmada ? 'Confirmada' : 'En revisión'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Form(
          key: _form,
          child: CampoEtiquetado(
            etiqueta: 'RUNSA *',
            child: TextFormField(
              controller: _runsa,
              decoration: decoracionCampo(icono: 'documento'),
              textCapitalization: TextCapitalization.characters,
              validator: requerido,
            ),
          ),
        ),
        const AvisoVetLink(
          titulo: 'Registro sanitario de la granja',
          texto: 'Actualizalo cuando el SENASAG te asigne uno nuevo.',
        ),
        BotonPrincipal(texto: _enviando ? 'Guardando...' : 'Guardar cambios', alPresionar: _enviando ? null : _guardar),
      ],
    );
  }
}
