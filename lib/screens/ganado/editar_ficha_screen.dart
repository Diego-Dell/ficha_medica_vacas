import 'package:flutter/material.dart';

import '../../logic/fichas.dart';
import '../../logic/granjas.dart';
import '../../models/animal.dart';
import '../../models/miembro.dart';
import '../../widgets/vetlink.dart';
import 'registro_guardado.dart';

// 1. Nueva ficha, o editar la ficha de [animal] (se abre desde su ficha).
class EditarFichaScreen extends StatefulWidget {
  const EditarFichaScreen({super.key, this.animal});

  final Animal? animal;

  @override
  State<EditarFichaScreen> createState() => _EditarFichaScreenState();
}

class _EditarFichaScreenState extends State<EditarFichaScreen> {
  final _form = GlobalKey<FormState>();
  final _arete = TextEditingController();
  final _nombre = TextEditingController();
  final _raza = TextEditingController();
  Animal? _animal;
  Etapa? _etapa;
  DateTime? _nacimiento;
  bool _estimado = false;
  bool _enviando = false;
  bool get _soloEtapa => _animal != null && !Granjas.instance.sesionAdministradora && Granjas.instance.rol == RolMiembro.veterinario;
  bool get _puedeCambiarEtapa => Granjas.instance.sesionAdministradora || _animal == null || Granjas.instance.rol != RolMiembro.trabajador;

  @override
  void initState() {
    super.initState();
    if (widget.animal != null) _cargar(widget.animal);
  }

  @override
  void dispose() {
    for (final c in [_arete, _nombre, _raza]) {
      c.dispose();
    }
    super.dispose();
  }

  // 2. Llena el formulario con la ficha a editar.
  void _cargar(Animal? animal) {
    _animal = animal;
    _arete.text = animal?.arete ?? '';
    _nombre.text = animal?.nombre ?? '';
    _raza.text = animal?.raza ?? '';
    _etapa = animal?.etapa;
    _nacimiento = animal?.nacimiento;
    _estimado = animal?.nacimientoEstimado ?? false;
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
    final error = _soloEtapa
        ? await Fichas.instance.actualizarEtapa(_animal!, _etapa!)
        : _animal != null ? await Fichas.instance.actualizar(animal) : await Fichas.instance.crear(animal);
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
      titulo: _animal == null ? 'Nueva ficha' : _soloEtapa ? 'Editar etapa' : 'Editar ficha',
      subtitulo: 'Los campos con * son obligatorios.',
      children: [
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_soloEtapa) Text(_animal!.titulo, style: Theme.of(context).textTheme.titleMedium),
              if (!_soloEtapa) ...[
              CampoEtiquetado(
                etiqueta: 'Identificación *',
                child: TextFormField(
                  controller: _arete,
                  decoration: decoracionCampo(),
                  textCapitalization: TextCapitalization.characters,
                  validator: textoEntre(1, 30),
                ),
              ),
              CampoEtiquetado(
                etiqueta: 'Nombre',
                child: TextFormField(
                  controller: _nombre,
                  validator: textoOpcional(60),
                  decoration: decoracionCampo(),
                  textCapitalization: TextCapitalization.words,
                ),
              ),
              CampoEtiquetado(
                etiqueta: 'Raza',
                child: TextFormField(
                  controller: _raza,
                  validator: textoOpcional(60),
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
                        borderRadius: BorderRadius.circular(radioCampo),
                        onTap: _elegirNacimiento,
                        child: InputDecorator(
                          decoration: decoracionCampo(icono: 'calendario'),
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
              ],
              CampoEtiquetado(
                etiqueta: _puedeCambiarEtapa ? 'Etapa *' : 'Etapa (solo consulta)',
                // 6. Etapa como selector de tres opciones.
                child: FormField<Etapa>(
                  key: ValueKey(_etapa),
                  initialValue: _etapa,
                  validator: (_) => _etapa == null ? 'Campo obligatorio' : null,
                  builder: (campo) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          for (final e in Etapa.values)
                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(right: e == Etapa.values.last ? 0 : 8),
                                child: _OpcionEtapa(
                                  texto: e.etiqueta,
                                  activa: _etapa == e,
                                  alElegir: _puedeCambiarEtapa ? () => setState(() => _etapa = e) : null,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (campo.hasError)
                        Padding(
                          padding: const EdgeInsets.only(top: 6, left: 12),
                          child: Text(campo.errorText!, style: const TextStyle(color: colorRojo, fontSize: 12)),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        BotonPrincipal(
          texto: _enviando ? 'Guardando...' : _soloEtapa ? 'Guardar etapa' : 'Guardar ficha',
          alPresionar: _enviando ? null : _guardar,
        ),
      ],
    );
  }
}

// 7. Botón de una etapa: verde suave cuando está elegida.
class _OpcionEtapa extends StatelessWidget {
  const _OpcionEtapa({required this.texto, required this.activa, required this.alElegir});

  final String texto;
  final bool activa;
  final VoidCallback? alElegir;

  @override
  Widget build(BuildContext context) => Material(
        color: activa ? colorVerdeSuave : colorSuperficie,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radioCampo),
          side: BorderSide(color: activa ? colorVerde : colorBorde, width: activa ? 1.5 : 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(radioCampo),
          onTap: alElegir,
          child: SizedBox(
            height: 48,
            child: Center(
              child: Text(texto, style: TextStyle(
                  fontWeight: activa ? FontWeight.w600 : FontWeight.w400,
                  color: activa ? colorVerde : colorTextoSuave)),
            ),
          ),
        ),
      );
}
