import 'package:flutter/material.dart';

import '../../logic/fichas.dart';
import '../../logic/granjas.dart';
import '../../models/animal.dart';
import '../../widgets/vetlink.dart';
import 'registro_guardado.dart';

// 1. "Ficha" del prototipo: crea una ficha o actualiza una existente.
class EditarFichaScreen extends StatefulWidget {
  const EditarFichaScreen({super.key});

  @override
  State<EditarFichaScreen> createState() => _EditarFichaScreenState();
}

class _EditarFichaScreenState extends State<EditarFichaScreen> {
  final _form = GlobalKey<FormState>();
  final _arete = TextEditingController();
  final _nombre = TextEditingController();
  final _raza = TextEditingController();
  final _fichas = Fichas.instance.activos();
  Animal? _animal;
  Etapa? _etapa;
  DateTime? _nacimiento;
  bool _estimado = false;
  bool _enviando = false;

  @override
  void dispose() {
    for (final c in [_arete, _nombre, _raza]) {
      c.dispose();
    }
    super.dispose();
  }

  // 2. Llena el formulario con la ficha elegida o lo vacía.
  void _cargar(Animal? animal) {
    setState(() {
      _animal = animal;
      _arete.text = animal?.arete ?? '';
      _nombre.text = animal?.nombre ?? '';
      _raza.text = animal?.raza ?? '';
      _etapa = animal?.etapa;
      _nacimiento = animal?.nacimiento;
      _estimado = animal?.nacimientoEstimado ?? false;
    });
  }

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
    // 3. Valida y evita envíos dobles.
    if (_enviando || !_form.currentState!.validate()) return;
    setState(() => _enviando = true);

    // 4. Mismo id al actualizar, así los registros siguen vinculados.
    final animal = Animal(
      id: _animal?.id ?? '',
      arete: _arete.text.trim(),
      nombre: _opcional(_nombre.text),
      raza: _opcional(_raza.text),
      etapa: _etapa!,
      nacimiento: _nacimiento,
      nacimientoEstimado: _nacimiento != null && _estimado,
    );
    final error = _animal != null ? await Fichas.instance.actualizar(animal) : await Fichas.instance.crear(animal);
    if (!mounted) return;
    setState(() => _enviando = false);

    // 5. Muestra el error o "Registro guardado" y vuelve.
    if (error != null) {
      avisar(context, error);
      return;
    }
    await mostrarRegistroGuardado(context);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return PantallaVetLink(
      encabezado: EncabezadoVetLink(granja: Granjas.instance.actual.nombre, alVolver: () => Navigator.pop(context)),
      titulo: 'Ficha',
      subtitulo: 'Creá una ficha o seleccioná una para actualizarla.',
      children: [
        FutureBuilder<List<Animal>>(
          future: _fichas,
          builder: (context, estado) => CampoEtiquetado(
            etiqueta: 'Ficha',
            child: DropdownButtonFormField<String?>(
              key: ValueKey(estado.data?.length),
              initialValue: _animal?.id,
              isExpanded: true,
              decoration: decoracionCampo(),
              items: [
                const DropdownMenuItem(value: null, child: Text('Nueva ficha')),
                for (final a in estado.data ?? const <Animal>[]) DropdownMenuItem(value: a.id, child: Text(a.titulo)),
              ],
              onChanged: (id) => _cargar(id == null ? null : estado.data!.firstWhere((a) => a.id == id)),
            ),
          ),
        ),
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CampoEtiquetado(
                etiqueta: 'Identificación *',
                child: TextFormField(
                  controller: _arete,
                  decoration: decoracionCampo(),
                  textCapitalization: TextCapitalization.characters,
                  validator: requerido,
                ),
              ),
              CampoEtiquetado(
                etiqueta: 'Nombre',
                child: TextFormField(
                  controller: _nombre,
                  decoration: decoracionCampo(),
                  textCapitalization: TextCapitalization.words,
                ),
              ),
              CampoEtiquetado(
                etiqueta: 'Raza',
                child: TextFormField(
                  controller: _raza,
                  decoration: decoracionCampo(),
                  textCapitalization: TextCapitalization.words,
                ),
              ),
              CampoEtiquetado(
                etiqueta: 'Nacimiento',
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: _elegirNacimiento,
                        child: InputDecorator(
                          decoration: decoracionCampo(),
                          child: Text(_nacimiento == null ? 'Sin registrar' : fechaCorta(_nacimiento!)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<bool>(
                        key: ValueKey(_estimado),
                        initialValue: _estimado,
                        isExpanded: true,
                        decoration: decoracionCampo(),
                        items: const [
                          DropdownMenuItem(value: false, child: Text('Conocido')),
                          DropdownMenuItem(value: true, child: Text('Estimado')),
                        ],
                        onChanged: (valor) => setState(() => _estimado = valor ?? false),
                      ),
                    ),
                  ],
                ),
              ),
              CampoEtiquetado(
                etiqueta: 'Etapa *',
                child: DropdownButtonFormField<Etapa>(
                  key: ValueKey(_etapa),
                  initialValue: _etapa,
                  isExpanded: true,
                  decoration: decoracionCampo(pista: 'Ternera / Vaquilla / Vaca'),
                  items: [for (final e in Etapa.values) DropdownMenuItem(value: e, child: Text(e.etiqueta))],
                  onChanged: (etapa) => setState(() => _etapa = etapa),
                  validator: (etapa) => etapa == null ? 'Campo obligatorio' : null,
                ),
              ),
            ],
          ),
        ),
        BotonPrincipal(
          texto: _enviando ? 'Guardando...' : 'Guardar ficha',
          alPresionar: _enviando ? null : _guardar,
        ),
      ],
    );
  }
}
