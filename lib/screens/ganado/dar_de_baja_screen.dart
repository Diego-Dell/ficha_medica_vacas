import 'package:flutter/material.dart';

import '../../logic/fichas.dart';
import '../../logic/granjas.dart';
import '../../models/animal.dart';
import '../../widgets/selector_animal.dart';
import '../../widgets/vetlink.dart';
import 'ficha_animal_screen.dart';

// 1. "Baja del animal" del prototipo; solo la ve el dueño.
class DarDeBajaScreen extends StatefulWidget {
  const DarDeBajaScreen({super.key});

  @override
  State<DarDeBajaScreen> createState() => _DarDeBajaScreenState();
}

class _DarDeBajaScreenState extends State<DarDeBajaScreen> {
  final _form = GlobalKey<FormState>();
  final _motivo = TextEditingController();
  Animal? _animal;
  DateTime _fecha = DateUtils.dateOnly(DateTime.now());
  bool _enviando = false;

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

  // 2. Ventana "¿Confirmar la baja?" del prototipo.
  Future<bool> _confirmar(Animal animal) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: colorFondo,
          title: const Text('¿Confirmar la baja?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${animal.titulo} · ${Granjas.instance.actual.nombre}'),
              const SizedBox(height: 8),
              const Text(
                'Se conservará el historial y no se admitirán nuevos eventos.',
                style: TextStyle(color: colorTextoSuave, fontSize: 12),
              ),
            ],
          ),
          actions: [
            BotonPrincipal(texto: 'Sí, dar de baja', color: colorRojo, alPresionar: () => Navigator.pop(context, true)),
            BotonSecundario(texto: 'Cancelar', alPresionar: () => Navigator.pop(context, false)),
          ],
        ),
      ) ??
      false;

  Future<void> _darDeBaja() async {
    // 3. Valida, pide confirmación y evita envíos dobles.
    final animal = _animal;
    if (_enviando || !_form.currentState!.validate() || animal == null) return;
    if (!await _confirmar(animal) || !mounted) return;
    setState(() => _enviando = true);

    final error = await Fichas.instance.darDeBaja(animal, _fecha, _motivo.text);
    if (!mounted) return;
    setState(() => _enviando = false);
    if (error != null) {
      avisar(context, error);
      return;
    }

    // 4. Muestra la ficha conservada después de la baja.
    try {
      final actual = await Fichas.instance.porId(animal.id);
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => FichaAnimalScreen(animal: actual)));
    } on Exception {
      if (!mounted) return;
      avisar(context, '${animal.titulo} se dio de baja');
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PantallaVetLink(
      encabezado: EncabezadoVetLink(granja: Granjas.instance.actual.nombre, alVolver: () => Navigator.pop(context)),
      titulo: 'Baja del animal',
      subtitulo: 'El historial del animal se conserva.',
      children: [
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SelectorAnimal(alElegir: (animal) => _animal = animal),
              CampoEtiquetado(
                etiqueta: 'Fecha de baja *',
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: _elegirFecha,
                  child: InputDecorator(decoration: decoracionCampo(), child: Text(fechaCorta(_fecha))),
                ),
              ),
              CampoEtiquetado(
                etiqueta: 'Motivo de baja *',
                child: TextFormField(
                  controller: _motivo,
                  decoration: decoracionCampo(pista: 'Venta del animal'),
                  textCapitalization: TextCapitalization.sentences,
                  validator: requerido,
                ),
              ),
            ],
          ),
        ),
        BotonPrincipal(
          texto: _enviando ? 'Confirmando...' : 'Confirmar baja',
          alPresionar: _enviando ? null : _darDeBaja,
        ),
      ],
    );
  }
}
