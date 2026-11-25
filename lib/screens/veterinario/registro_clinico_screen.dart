import 'package:flutter/material.dart';

import '../../logic/sincronizacion.dart';
import '../../logic/clinica.dart';
import '../../logic/fichas.dart';
import '../../logic/granjas.dart';
import '../../models/animal.dart';
import '../../models/miembro.dart';
import '../../models/registro_clinico.dart';
import '../../widgets/selector_animal.dart';
import '../../widgets/vetlink.dart';
import '../ganado/ficha_animal_screen.dart';
import '../ganado/registro_guardado.dart';

// 1. Dos formularios con el mismo marco y guardado: Clínica y Reproducción.
class RegistroClinicoScreen extends StatefulWidget {
  const RegistroClinicoScreen({
    super.key,
    this.reproductivo = false,
    this.registro,
  });
  final bool reproductivo;
  final RegistroClinico? registro;
  @override
  State<RegistroClinicoScreen> createState() => _RegistroClinicoScreenState();
}

class _RegistroClinicoScreenState extends State<RegistroClinicoScreen> {
  final _formulario = GlobalKey<FormState>();
  final _signos = TextEditingController();
  final _diagnostico = TextEditingController();
  final _indicaciones = TextEditingController();
  final _detalle = TextEditingController();
  Animal? _animal;
  DateTime _fecha = DateUtils.dateOnly(DateTime.now());
  DateTime? _proximoControl, _partoProbable;
  String _tipo = 'Diagnostico',
      _aptitud = '',
      _prenez = 'NoEvaluada',
      _evento = 'Valoracion';
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    final r = widget.registro;
    if (r == null) return;
    _fecha = DateUtils.dateOnly(r.fecha);
    _detalle.text = r.detalle;
    if (r.reproductivo) {
      _evento = r.tipo;
      _aptitud = r.aptitud ?? '';
      _prenez = r.prenez ?? 'NoEvaluada';
      _proximoControl = r.proximoControl == null
          ? null
          : DateTime.parse(r.proximoControl!);
      _partoProbable = r.partoProbable == null
          ? null
          : DateTime.parse(r.partoProbable!);
    } else {
      _tipo = r.tipo;
    }
    _cargarAnimal(r.animalId);
  }

  Future<void> _cargarAnimal(String id) async {
    try {
      final animal = await Fichas.instance.porId(id);
      if (mounted) setState(() => _animal = animal);
    } on Exception {
      if (mounted) {
        avisar(
          context,
          'No se pudo cargar el animal. Volvé a abrir el registro',
        );
      }
    }
  }

  @override
  void dispose() {
    for (final campo in [_signos, _diagnostico, _indicaciones, _detalle]) {
      campo.dispose();
    }
    super.dispose();
  }

  // 2. Fechas de registro hasta hoy; las fechas previstas pueden ser futuras.
  Widget _campoFecha(
    String etiqueta,
    DateTime? valor,
    ValueChanged<DateTime?> cambiar, {
    bool prevista = false,
  }) => CampoEtiquetado(
    etiqueta: etiqueta,
    child: Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _guardando
                ? null
                : () async {
                    final minimo = prevista ? _fecha : DateTime(2000);
                    final maximo = prevista
                        ? DateTime(DateTime.now().year + 5, 12, 31)
                        : DateUtils.dateOnly(DateTime.now());
                    final inicial = valor == null || valor.isBefore(minimo)
                        ? minimo
                        : valor;
                    final elegida = await showDatePicker(
                      context: context,
                      initialDate: inicial,
                      firstDate: minimo,
                      lastDate: maximo,
                    );
                    if (elegida != null && mounted) {
                      setState(() => cambiar(elegida));
                    }
                  },
            child: Text(
              valor == null ? 'Seleccionar fecha' : fechaCorta(valor),
            ),
          ),
        ),
        if (prevista && valor != null)
          IconButton(
            tooltip: 'Quitar fecha',
            onPressed: _guardando ? null : () => setState(() => cambiar(null)),
            icon: const Icon(Icons.close),
          ),
      ],
    ),
  );

  Widget _opciones(
    String etiqueta,
    String valor,
    Map<String, String> opciones,
    ValueChanged<String> cambiar,
  ) => CampoEtiquetado(
    etiqueta: etiqueta,
    child: DropdownButtonFormField<String>(
      key: ValueKey('$etiqueta:$valor'),
      initialValue: valor,
      isExpanded: true,
      decoration: decoracionCampo(),
      items: [
        for (final opcion in opciones.entries)
          DropdownMenuItem(value: opcion.key, child: Text(opcion.value)),
      ],
      onChanged: _guardando ? null : (v) => setState(() => cambiar(v!)),
    ),
  );

  Widget _texto(
    String etiqueta,
    TextEditingController controlador, {
    bool obligatorio = true,
  }) => CampoEtiquetado(
    etiqueta: etiqueta,
    child: TextFormField(
      controller: controlador,
      minLines: 2,
      maxLines: 5,
      decoration: decoracionCampo(),
      validator: obligatorio ? requerido : null,
    ),
  );

  // Opciones visibles como en el diseño; se acomodan en pantallas angostas.
  Widget _seleccion(
    String etiqueta,
    String valor,
    Map<String, String> opciones,
    ValueChanged<String> cambiar,
  ) => CampoEtiquetado(
    etiqueta: etiqueta,
    child: Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final opcion in opciones.entries)
          ChoiceChip(
            label: Text(opcion.value),
            selected: valor == opcion.key,
            selectedColor: colorVerdeSuave,
            onSelected: _guardando
                ? null
                : (_) => setState(() => cambiar(opcion.key)),
          ),
      ],
    ),
  );

  // 3. Se agrega un registro nuevo; parto o pérdida no borran antecedentes.
  Future<void> _guardar() async {
    if (_guardando || !_formulario.currentState!.validate()) return;
    final animal = _animal;
    if (animal == null) {
      avisar(context, 'Elegí un animal');
      return;
    }
    if (animal.deBaja ||
        (!Granjas.instance.sesionAdministradora &&
            Granjas.instance.rol != RolMiembro.veterinario)) {
      avisar(
        context,
        'Solo el veterinario puede registrar en una ficha activa',
      );
      return;
    }
    if (widget.reproductivo) {
      if ((_proximoControl?.isBefore(_fecha) ?? false) ||
          (_partoProbable?.isBefore(_fecha) ?? false)) {
        avisar(
          context,
          'Las fechas previstas no pueden ser anteriores a la valoración',
        );
        return;
      }
      if (_evento != 'Valoracion' && _prenez != 'Vacia') {
        avisar(
          context,
          'Para registrar un parto o una pérdida, indicá No gestante',
        );
        return;
      }
    }
    final datos = <String, dynamic>{
      'fichaBovinaId': animal.id,
      'fecha': _fecha.toUtc().toIso8601String(),
      if (widget.reproductivo) ...{
        'tipo': _evento,
        'aptitud': _aptitud.isEmpty ? null : _aptitud,
        'prenez': _prenez,
        'proximoControl': _proximoControl == null
            ? null
            : fechaApi(_proximoControl!),
        'partoProbable': _prenez == 'Prenada' && _partoProbable != null
            ? fechaApi(_partoProbable!)
            : null,
        'detalle': _detalle.text.trim(),
      } else ...{
        'tipo': _tipo,
        'detalle': widget.registro != null
            ? _detalle.text.trim()
            : [
                'Signos observados: ${_signos.text.trim()}',
                'Diagnóstico: ${_diagnostico.text.trim()}',
                if (_indicaciones.text.trim().isNotEmpty)
                  'Indicaciones: ${_indicaciones.text.trim()}',
              ].join('\n'),
      },
    };
    setState(() => _guardando = true);
    final error = widget.registro == null
        ? await Clinica.instance.registrar(
            reproductivo: widget.reproductivo,
            datos: datos,
            animal: animal.arete,
          )
        : await Clinica.instance.corregir(widget.registro!, datos);
    if (!mounted) return;
    setState(() => _guardando = false);
    if (error != null) {
      avisar(context, error);
      return;
    }
    await mostrarRegistroGuardado(
      context,
      estado: widget.registro == null ? Sincronizacion.instance.ultimoEstado : null,
    );
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_guardando,
    child: PantallaVetLink(
      titulo: widget.reproductivo ? 'Reproducción' : 'Clínica',
      subtitulo: widget.reproductivo
          ? 'Registrá la valoración y los eventos reproductivos.'
          : 'Registrá la atención médica.',
      encabezado: EncabezadoVetLink(
        granja: Granjas.instance.actual.nombre,
        alVolver: _guardando ? null : () => Navigator.pop(context),
      ),
      children: [
        Form(
          key: _formulario,
          child: AbsorbPointer(
            absorbing: _guardando,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.registro == null)
                  SelectorAnimal(
                    alElegir: (animal) => setState(() => _animal = animal),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      _animal == null
                          ? 'Cargando animal...'
                          : '${_animal!.nombre ?? ''} · ${_animal!.arete}',
                    ),
                  ),
                _campoFecha(
                  widget.reproductivo
                      ? 'Fecha de valoración *'
                      : 'Fecha de atención *',
                  _fecha,
                  (fecha) => _fecha = fecha!,
                ),
                if (widget.reproductivo) ...[
                  _seleccion(
                    'Aptitud *',
                    _aptitud,
                    aptitudes,
                    (v) => _aptitud = v,
                  ),
                  _seleccion('Preñez *', _prenez, estadosPrenez, (v) {
                    _prenez = v;
                    if (v != 'Prenada') _partoProbable = null;
                  }),
                  _opciones(
                    'Parto o pérdida',
                    _evento,
                    eventosReproductivos,
                    (v) => _evento = v,
                  ),
                  _texto('Detalle *', _detalle),
                  _campoFecha(
                    'Próximo control (opcional)',
                    _proximoControl,
                    (v) => _proximoControl = v,
                    prevista: true,
                  ),
                  if (_prenez == 'Prenada')
                    _campoFecha(
                      'Fecha probable de parto (opcional)',
                      _partoProbable,
                      (v) => _partoProbable = v,
                      prevista: true,
                    ),
                ] else ...[
                  _opciones(
                    'Tipo de atención *',
                    _tipo,
                    tiposAtencion,
                    (v) => _tipo = v,
                  ),
                  if (widget.registro != null)
                    _texto('Detalle *', _detalle)
                  else ...[
                    _texto('Signos observados *', _signos),
                    _texto('Diagnóstico *', _diagnostico),
                    _texto(
                      'Indicaciones (opcional)',
                      _indicaciones,
                      obligatorio: false,
                    ),
                  ],
                ],
                BotonPrincipal(
                  texto: _guardando
                      ? 'Guardando…'
                      : widget.reproductivo
                      ? 'Guardar valoración'
                      : 'Guardar registro',
                  alPresionar: _guardando ? null : _guardar,
                ),
                BotonSecundario(
                  texto: 'Ver antecedentes del animal',
                  alPresionar: _animal == null || _guardando
                      ? null
                      : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FichaAnimalScreen(animal: _animal!),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
