import 'package:flutter/material.dart';

import '../../logic/cuidados.dart';
import '../../logic/granjas.dart';
import '../../logic/sesion.dart';
import '../../models/animal.dart';
import '../../widgets/selector_animal.dart';
import '../../widgets/vetlink.dart';
import '../ganado/registro_guardado.dart';

/// Registro de lo observado por el trabajador y el cuidado que realizó.
class ObservacionScreen extends StatefulWidget {
  const ObservacionScreen({super.key, this.animal});
  final Animal? animal;

  @override
  State<ObservacionScreen> createState() => _ObservacionScreenState();
}

class _ObservacionScreenState extends State<ObservacionScreen> {
  final _form = GlobalKey<FormState>();
  final _observado = TextEditingController();
  final _cuidado = TextEditingController();
  late Animal? _animal = widget.animal;
  DateTime _fecha = DateTime.now();
  bool _guardando = false;

  @override
  void dispose() {
    _observado.dispose();
    _cuidado.dispose();
    super.dispose();
  }

  Future<void> _elegirFecha() async {
    final hoy = DateTime.now();
    final dia = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(hoy.year - 2),
      lastDate: hoy,
    );
    if (dia == null || !mounted) {
      return;
    }
    final hora = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_fecha),
    );
    if (hora == null || !mounted) {
      return;
    }
    setState(
      () => _fecha = DateTime(
        dia.year,
        dia.month,
        dia.day,
        hora.hour,
        hora.minute,
      ),
    );
  }

  Future<void> _guardar() async {
    if (_guardando || !_form.currentState!.validate()) {
      return;
    }
    final cuentaId = Sesion.instance.id;
    if (cuentaId == null || _animal == null) {
      avisar(context, 'Elegí un animal e iniciá sesión.');
      return;
    }
    setState(() => _guardando = true);
    try {
      await Cuidados.instance.registrarObservacion(
        animal: _animal!,
        cuentaId: cuentaId,
        fecha: _fecha,
        observado: _observado.text,
        cuidado: _cuidado.text,
      );
      if (!mounted) {
        return;
      }
      await mostrarRegistroGuardado(context);
      if (mounted) {
        Navigator.pop(context, true);
      }
    } on ErrorCuidados catch (e) {
      if (mounted) {
        avisar(context, e.mensaje);
      }
    } finally {
      if (mounted) {
        setState(() => _guardando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => PantallaVetLink(
    titulo: 'Observación',
    subtitulo: 'Describí lo observado y el cuidado realizado.',
    encabezado: EncabezadoVetLink(
      granja: Granjas.instance.actual.nombre,
      alVolver: () => Navigator.pop(context),
    ),
    children: [
      Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SelectorAnimal(
              inicial: widget.animal,
              alElegir: (animal) => setState(() => _animal = animal),
            ),
            CampoEtiquetado(
              etiqueta: 'Fecha y hora *',
              child: _CampoFecha(fecha: _fecha, alPresionar: _elegirFecha),
            ),
            CampoEtiquetado(
              etiqueta: 'Lo observado *',
              child: TextFormField(
                controller: _observado,
                minLines: 2,
                maxLines: 4,
                maxLength: 1000,
                decoration: decoracionCampo(pista: '¿Qué viste en el animal?'),
                validator: requerido,
              ),
            ),
            CampoEtiquetado(
              etiqueta: 'Cuidado realizado *',
              child: TextFormField(
                controller: _cuidado,
                minLines: 2,
                maxLines: 4,
                maxLength: 1000,
                decoration: decoracionCampo(pista: '¿Qué hiciste?'),
                validator: requerido,
              ),
            ),
            const AvisoVetLink(
              titulo: 'Queda en el historial',
              texto: 'El veterinario podrá revisar la observación en la ficha del animal.',
            ),
            BotonPrincipal(
              texto: _guardando ? 'Guardando…' : 'Guardar observación',
              alPresionar: _guardando ? null : _guardar,
            ),
          ],
        ),
      ),
    ],
  );
}

/// Aplicación real de una indicación previamente creada para el mismo animal.
class AplicacionScreen extends StatefulWidget {
  const AplicacionScreen({super.key, this.animal});
  final Animal? animal;

  @override
  State<AplicacionScreen> createState() => _AplicacionScreenState();
}

class _AplicacionScreenState extends State<AplicacionScreen> {
  final _form = GlobalKey<FormState>();
  final _dosis = TextEditingController();
  final _unidad = TextEditingController();
  final _observacion = TextEditingController();
  late Animal? _animal = widget.animal;
  Future<List<Indicacion>>? _indicaciones;
  Indicacion? _indicacion;
  DateTime _fecha = DateTime.now();
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    if (_animal != null) {
      _indicaciones = Cuidados.instance.indicacionesDe(_animal!);
    }
  }

  @override
  void dispose() {
    _dosis.dispose();
    _unidad.dispose();
    _observacion.dispose();
    super.dispose();
  }

  void _elegirAnimal(Animal animal) {
    setState(() {
      _animal = animal;
      _indicacion = null;
      _indicaciones = Cuidados.instance.indicacionesDe(animal);
      _dosis.clear();
      _unidad.clear();
    });
  }

  void _elegirIndicacion(Indicacion? indicacion) {
    setState(() {
      _indicacion = indicacion;
      _dosis.text = indicacion?.dosis?.toString() ?? '';
      _unidad.text = indicacion?.unidad ?? '';
    });
  }

  Future<void> _elegirFecha() async {
    final hoy = DateTime.now();
    final dia = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(hoy.year - 2),
      lastDate: hoy,
    );
    if (dia == null || !mounted) {
      return;
    }
    final hora = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_fecha),
    );
    if (hora == null || !mounted) {
      return;
    }
    setState(
      () => _fecha = DateTime(
        dia.year,
        dia.month,
        dia.day,
        hora.hour,
        hora.minute,
      ),
    );
  }

  Future<void> _guardar() async {
    if (_guardando || !_form.currentState!.validate()) {
      return;
    }
    final cuentaId = Sesion.instance.id;
    final dosis = double.tryParse(_dosis.text.trim().replaceAll(',', '.'));
    if (cuentaId == null ||
        _animal == null ||
        _indicacion == null ||
        dosis == null) {
      avisar(context, 'Completá la indicación y la dosis.');
      return;
    }
    setState(() => _guardando = true);
    try {
      await Cuidados.instance.registrarAplicacion(
        animal: _animal!,
        indicacion: _indicacion!,
        cuentaId: cuentaId,
        fecha: _fecha,
        dosis: dosis,
        unidad: _unidad.text,
        observacion: _observacion.text,
      );
      if (!mounted) {
        return;
      }
      await mostrarRegistroGuardado(context);
      if (mounted) {
        Navigator.pop(context, true);
      }
    } on ErrorCuidados catch (e) {
      if (mounted) {
        avisar(context, e.mensaje);
      }
    } finally {
      if (mounted) {
        setState(() => _guardando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => PantallaVetLink(
    titulo: 'Aplicación',
    subtitulo: 'Registrá la aplicación de una indicación.',
    encabezado: EncabezadoVetLink(
      granja: Granjas.instance.actual.nombre,
      alVolver: () => Navigator.pop(context),
    ),
    children: [
      Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SelectorAnimal(inicial: widget.animal, alElegir: _elegirAnimal),
            FutureBuilder<List<Indicacion>>(
              future: _indicaciones,
              builder: (context, estado) {
                if (_animal == null) {
                  return const AvisoVetLink(
                    titulo: 'Elegí un animal para ver sus indicaciones.',
                  );
                }
                if (estado.hasError) {
                  return const AvisoVetLink(
                    titulo: 'No se pudieron cargar las indicaciones.',
                    advertencia: true,
                  );
                }
                if (estado.connectionState != ConnectionState.done || !estado.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final opciones = estado.data!;
                if (opciones.isEmpty) {
                  return const AvisoVetLink(
                    titulo: 'No hay indicaciones vigentes para este animal.',
                    advertencia: true,
                  );
                }
                return CampoEtiquetado(
                  etiqueta: 'Indicación *',
                  child: DropdownButtonFormField<Indicacion>(
                    key: ValueKey(_animal!.id),
                    initialValue: _indicacion,
                    isExpanded: true,
                    decoration: decoracionCampo(
                      pista: 'Elegir tratamiento o prevención',
                    ),
                    items: [
                      for (final i in opciones)
                        DropdownMenuItem(
                          value: i,
                          child: Text(
                            '${i.tipo} · ${i.nombre}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: _elegirIndicacion,
                    validator: (valor) =>
                        valor == null ? 'Elegí una indicación' : null,
                  ),
                );
              },
            ),
            if (_indicacion?.esTratamiento == true) AvisoVetLink(
              titulo: 'Indicación del veterinario',
              texto: [
                if (_indicacion!.via != null) 'Vía: ${_indicacion!.via}',
                if (_indicacion!.frecuencia != null) 'Frecuencia: ${_indicacion!.frecuencia}',
                if (_indicacion!.duracion != null) 'Duración: ${_indicacion!.duracion}',
                if (_indicacion!.retiro?.isNotEmpty == true) 'Retiro: ${_indicacion!.retiro}',
              ].join('\n'),
            ),
            CampoEtiquetado(
              etiqueta: 'Fecha y hora de aplicación *',
              child: _CampoFecha(fecha: _fecha, alPresionar: _elegirFecha),
            ),
            Row(
              children: [
                Expanded(
                  child: CampoEtiquetado(
                    etiqueta: 'Dosis *',
                    child: TextFormField(
                      controller: _dosis,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: decoracionCampo(pista: '0.0'),
                      validator: (texto) {
                        final valor = double.tryParse(
                          (texto ?? '').trim().replaceAll(',', '.'),
                        );
                        return valor == null || !valor.isFinite || valor <= 0
                            ? 'Dosis positiva'
                            : null;
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CampoEtiquetado(
                    etiqueta: 'Unidad *',
                    child: TextFormField(
                      controller: _unidad,
                      maxLength: 30,
                      decoration: decoracionCampo(pista: 'mL, mg…'),
                      validator: requerido,
                    ),
                  ),
                ),
              ],
            ),
            CampoEtiquetado(
              etiqueta: 'Observaciones',
              child: TextFormField(
                controller: _observacion,
                minLines: 2,
                maxLines: 4,
                maxLength: 1000,
                decoration: decoracionCampo(
                  pista: 'Reacciones o detalles de la aplicación',
                ),
              ),
            ),
            BotonPrincipal(
              texto: _guardando ? 'Registrando…' : 'Registrar aplicación',
              alPresionar: _guardando ? null : _guardar,
            ),
          ],
        ),
      ),
    ],
  );
}

class _CampoFecha extends StatelessWidget {
  const _CampoFecha({required this.fecha, required this.alPresionar});
  final DateTime fecha;
  final VoidCallback alPresionar;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(radioCampo),
    onTap: alPresionar,
    child: InputDecorator(
      decoration: decoracionCampo(icono: 'calendario'),
      child: Text(
        '${fechaCorta(fecha)} · ${TimeOfDay.fromDateTime(fecha).format(context)}',
      ),
    ),
  );
}
