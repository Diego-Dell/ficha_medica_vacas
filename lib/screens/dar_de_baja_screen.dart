import 'package:flutter/material.dart';

import '../logic/granjas.dart';
import '../widgets/vetlink.dart';

class DarDeBajaScreen extends StatefulWidget {
  const DarDeBajaScreen({super.key});

  @override
  State<DarDeBajaScreen> createState() => _DarDeBajaScreenState();
}

class _DarDeBajaScreenState extends State<DarDeBajaScreen> {
  final _form = GlobalKey<FormState>();
  final _motivo = TextEditingController();
  DateTime _fecha = DateUtils.dateOnly(DateTime.now());

  @override
  void dispose() {
    _motivo.dispose();
    super.dispose();
  }

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

  void _confirmar() {
    if (!_form.currentState!.validate()) return;
    final datos = Granjas.instance;
    final animal = datos.animalParaBaja!;
    datos.darDeBaja(animal, _fecha, _motivo.text.trim());
    avisar(context, '${animal.nombre} se dio de baja. Su ficha y su historial se conservan');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final datos = Granjas.instance;
    final animal = datos.animalParaBaja;
    final tema = Theme.of(context).textTheme;
    void volver() => Navigator.pop(context);

    return PantallaVetLink(
      encabezado: EncabezadoVetLink(granja: datos.actual.nombre, alVolver: volver),
      barraInferior: BarraVetLink(alVolver: volver),
      titulo: 'Dar de baja',
      subtitulo: 'La ficha y el historial se conservarán.',
      children: animal == null
          ? [
              Text('No hay animales para dar de baja.', style: tema.bodyMedium?.copyWith(color: colorTextoSuave)),
              const SizedBox(height: 12),
              BotonSecundario(texto: 'Volver', alPresionar: volver),
            ]
          : [
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(color: colorVerdeSuave, borderRadius: BorderRadius.circular(10)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${animal.nombre} · ${animal.arete}',
                      style: tema.titleSmall?.copyWith(color: colorVerdeOscuro, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${animal.categoria} · ${animal.raza} · ${datos.actual.nombre}',
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
              BotonPrincipal(texto: 'Confirmar baja', color: colorRojo, alPresionar: _confirmar),
              BotonSecundario(texto: 'Volver', alPresionar: volver),
            ],
    );
  }
}
