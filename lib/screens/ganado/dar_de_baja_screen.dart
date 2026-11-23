import 'package:flutter/material.dart';

import '../../logic/fichas.dart';
import '../../logic/granjas.dart';
import '../../models/animal.dart';
import '../../widgets/vetlink.dart';

// 1. "Baja del animal": se abre desde la ficha; solo la ve el dueño.
class DarDeBajaScreen extends StatefulWidget {
  const DarDeBajaScreen({super.key, required this.animal});

  final Animal animal;

  @override
  State<DarDeBajaScreen> createState() => _DarDeBajaScreenState();
}

class _DarDeBajaScreenState extends State<DarDeBajaScreen> {
  final _form = GlobalKey<FormState>();
  final _motivo = TextEditingController();
  late final Animal _animal = widget.animal;
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
        builder: (context) => VentanaVetLink(
          icono: 'alerta',
          peligro: true,
          titulo: '¿Confirmar la baja?',
          texto: '${animal.titulo} · ${Granjas.instance.actual.nombre}. Se conservará el historial y no se admitirán nuevos eventos.',
          acciones: [
            BotonPrincipal(texto: 'Sí, dar de baja', color: colorRojo, alPresionar: () => Navigator.pop(context, true)),
            BotonSecundario(texto: 'Cancelar', alPresionar: () => Navigator.pop(context, false)),
          ],
        ),
      ) ??
      false;

  Future<void> _darDeBaja() async {
    // 3. Valida, pide confirmación y evita envíos dobles.
    final animal = _animal;
    if (_enviando || !_form.currentState!.validate()) return;
    if (!await _confirmar(animal) || !mounted) return;
    setState(() => _enviando = true);

    final error = await Fichas.instance.darDeBaja(animal, _fecha, _motivo.text);
    if (!mounted) return;
    setState(() => _enviando = false);
    if (error != null) {
      avisar(context, error);
      return;
    }

    // 4. Vuelve a la ficha, que se muestra conservada después de la baja.
    Navigator.pop(context, true);
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
              Tarjeta(
                child: Row(
                  children: [
                    const BurbujaIcono('ganado', tam: 40),
                    const SizedBox(width: 12),
                    Expanded(child: Text(_animal.titulo, style: Theme.of(context).textTheme.titleMedium)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              CampoEtiquetado(
                etiqueta: 'Fecha de baja *',
                child: InkWell(
                  borderRadius: BorderRadius.circular(radioCampo),
                  onTap: _elegirFecha,
                  child: InputDecorator(decoration: decoracionCampo(icono: 'calendario'), child: Text(fechaCorta(_fecha))),
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
          color: colorRojo,
          alPresionar: _enviando ? null : _darDeBaja,
        ),
      ],
    );
  }
}
