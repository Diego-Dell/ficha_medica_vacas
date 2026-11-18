import 'package:flutter/material.dart';

import '../../logic/fichas.dart';
import '../../logic/granjas.dart';
import '../../models/animal.dart';
import '../../widgets/vetlink.dart';

class DarDeBajaScreen extends StatefulWidget {
  const DarDeBajaScreen({super.key, required this.animal});

  final Animal animal;

  @override
  State<DarDeBajaScreen> createState() => _DarDeBajaScreenState();
}

class _DarDeBajaScreenState extends State<DarDeBajaScreen> {
  final _form = GlobalKey<FormState>();
  final _motivo = TextEditingController();
  DateTime _fecha = DateUtils.dateOnly(DateTime.now());
  bool _enviando = false;

  @override
  void dispose() {
    _motivo.dispose();
    super.dispose();
  }

  /// 1. Abre el calendario sin permitir fechas futuras.
  Future<void> _elegirFecha() async {
    final hoy = DateUtils.dateOnly(DateTime.now());
    final elegida = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(hoy.year - 10),
      lastDate: hoy,
    );
    if (elegida != null) setState(() => _fecha = elegida);
  }

  Future<void> _confirmar() async {
    // 1. Valida el formulario y evita envíos dobles.
    if (_enviando || !_form.currentState!.validate()) return;
    setState(() => _enviando = true);

    // 2. Guarda la fecha y el motivo en Supabase.
    final animal = widget.animal;
    final error = await Fichas.instance.darDeBaja(animal, _fecha, _motivo.text);
    if (!mounted) return;
    setState(() => _enviando = false);

    // 3. Muestra el error o avisa el resultado y vuelve a la ficha.
    if (error != null) {
      avisar(context, error);
      return;
    }
    avisar(context, '${animal.titulo} se dio de baja. Su ficha y su historial se conservan');
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final granja = Granjas.instance.actual.nombre;
    final tema = Theme.of(context).textTheme;
    final animal = widget.animal;
    void volver() => Navigator.pop(context);

    return PantallaVetLink(
      encabezado: EncabezadoVetLink(granja: granja, alVolver: volver),
      titulo: 'Dar de baja',
      subtitulo: 'La ficha y el historial se conservarán.',
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(color: colorVerdeSuave, borderRadius: BorderRadius.circular(10)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                animal.titulo,
                style: tema.titleSmall?.copyWith(color: colorVerdeOscuro, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                [animal.etapa.etiqueta, if (animal.raza != null) animal.raza!, granja].join(' · '),
                style: tema.bodySmall?.copyWith(color: colorTextoSuave),
              ),
            ],
          ),
        ),
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CampoEtiquetado(
                etiqueta: 'Fecha de baja *',
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: _elegirFecha,
                  child: InputDecorator(decoration: decoracionCampo(), child: Text(fechaCorta(_fecha))),
                ),
              ),
              CampoEtiquetado(
                etiqueta: 'Motivo *',
                child: TextFormField(
                  controller: _motivo,
                  decoration: decoracionCampo(pista: 'Venta del animal'),
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 3,
                  validator: requerido,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(color: colorAmbarFondo, borderRadius: BorderRadius.circular(10)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Revisá antes de confirmar',
                style: tema.labelLarge?.copyWith(color: colorAmbarTexto, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                'El animal dado de baja no admitirá nuevos eventos.',
                style: tema.bodySmall?.copyWith(color: colorAmbarTexto),
              ),
            ],
          ),
        ),
        BotonPrincipal(
          texto: _enviando ? 'Confirmando...' : 'Confirmar baja',
          color: colorRojo,
          alPresionar: _enviando ? null : _confirmar,
        ),
        BotonSecundario(texto: 'Volver', alPresionar: volver),
      ],
    );
  }
}
