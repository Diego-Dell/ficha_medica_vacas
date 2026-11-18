import 'package:flutter/material.dart';

import '../../logic/fichas.dart';
import '../../logic/granjas.dart';
import '../../models/animal.dart';
import '../../widgets/vetlink.dart';

/// Crea una ficha nueva o, con [animal], edita sus datos generales.
class EditarFichaScreen extends StatefulWidget {
  const EditarFichaScreen({super.key, this.animal});

  final Animal? animal;

  @override
  State<EditarFichaScreen> createState() => _EditarFichaScreenState();
}

class _EditarFichaScreenState extends State<EditarFichaScreen> {
  final _form = GlobalKey<FormState>();
  late final _arete = TextEditingController(text: widget.animal?.arete);
  late final _nombre = TextEditingController(text: widget.animal?.nombre);
  late final _raza = TextEditingController(text: widget.animal?.raza);
  late Etapa? _etapa = widget.animal?.etapa;
  late DateTime? _nacimiento = widget.animal?.nacimiento;
  late bool _estimado = widget.animal?.nacimientoEstimado ?? false;
  bool _enviando = false;

  bool get _editando => widget.animal != null;

  @override
  void dispose() {
    for (final c in [_arete, _nombre, _raza]) {
      c.dispose();
    }
    super.dispose();
  }

  /// 1. Abre el calendario sin permitir fechas futuras.
  Future<void> _elegirNacimiento() async {
    final hoy = DateUtils.dateOnly(DateTime.now());
    final elegida = await showDatePicker(
      context: context,
      initialDate: _nacimiento ?? hoy,
      firstDate: DateTime(hoy.year - 30),
      lastDate: hoy,
    );
    if (elegida != null) setState(() => _nacimiento = elegida);
  }

  String? _opcional(String texto) => texto.trim().isEmpty ? null : texto.trim();

  Future<void> _guardar() async {
    // 1. Valida el formulario y evita envíos dobles.
    if (_enviando || !_form.currentState!.validate()) return;
    setState(() => _enviando = true);

    // 2. Arma la ficha con el mismo id si se está editando, así sus registros siguen vinculados.
    final animal = Animal(
      id: widget.animal?.id ?? '',
      arete: _arete.text.trim(),
      nombre: _opcional(_nombre.text),
      raza: _opcional(_raza.text),
      etapa: _etapa!,
      nacimiento: _nacimiento,
      nacimientoEstimado: _nacimiento != null && _estimado,
    );
    final error = _editando ? await Fichas.instance.actualizar(animal) : await Fichas.instance.crear(animal);
    if (!mounted) return;
    setState(() => _enviando = false);

    // 3. Muestra el error o avisa el resultado y vuelve.
    if (error != null) {
      avisar(context, error);
      return;
    }
    avisar(context, _editando ? 'Se guardaron los cambios de ${animal.titulo}' : 'Se creó la ficha de ${animal.titulo}');
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    void volver() => Navigator.pop(context);
    return PantallaVetLink(
      encabezado: EncabezadoVetLink(granja: Granjas.instance.actual.nombre, alVolver: volver),
      titulo: _editando ? 'Editar ficha' : 'Nueva ficha',
      subtitulo: 'La identificación no se puede repetir dentro de la granja.',
      children: [
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CampoEtiquetado(
                etiqueta: 'Identificación *',
                child: TextFormField(
                  controller: _arete,
                  decoration: decoracionCampo(pista: '0842'),
                  textCapitalization: TextCapitalization.characters,
                  validator: requerido,
                ),
              ),
              CampoEtiquetado(
                etiqueta: 'Nombre',
                child: TextFormField(
                  controller: _nombre,
                  decoration: decoracionCampo(pista: 'Lucera'),
                  textCapitalization: TextCapitalization.words,
                ),
              ),
              CampoEtiquetado(
                etiqueta: 'Raza',
                child: TextFormField(
                  controller: _raza,
                  decoration: decoracionCampo(pista: 'Holstein'),
                  textCapitalization: TextCapitalization.words,
                ),
              ),
              CampoEtiquetado(
                etiqueta: 'Etapa *',
                child: DropdownButtonFormField<Etapa>(
                  initialValue: _etapa,
                  decoration: decoracionCampo(pista: 'Elegir etapa'),
                  items: [for (final e in Etapa.values) DropdownMenuItem(value: e, child: Text(e.etiqueta))],
                  onChanged: (etapa) => setState(() => _etapa = etapa),
                  validator: (etapa) => etapa == null ? 'Campo obligatorio' : null,
                ),
              ),
              CampoEtiquetado(
                etiqueta: 'Nacimiento',
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: _elegirNacimiento,
                  child: InputDecorator(
                    decoration: decoracionCampo(),
                    child: Text(_nacimiento == null ? 'Sin registrar' : fechaCorta(_nacimiento!)),
                  ),
                ),
              ),
              if (_nacimiento != null)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('La fecha de nacimiento es estimada'),
                  value: _estimado,
                  onChanged: (valor) => setState(() => _estimado = valor ?? false),
                ),
            ],
          ),
        ),
        BotonPrincipal(
          texto: _enviando ? 'Guardando...' : 'Guardar ficha',
          alPresionar: _enviando ? null : _guardar,
        ),
        BotonSecundario(texto: 'Volver', alPresionar: volver),
      ],
    );
  }
}
