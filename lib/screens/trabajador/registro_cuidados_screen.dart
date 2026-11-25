import 'package:flutter/material.dart';

import '../../logic/cuidados.dart';
import '../../logic/dosis.dart';
import '../../logic/granjas.dart';
import '../../logic/sesion.dart';
import '../../models/animal.dart';
import '../../widgets/selector_animal.dart';
import '../../widgets/campos_indicacion.dart';
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
      final estado = await Cuidados.instance.registrarObservacion(
        animal: _animal!,
        cuentaId: cuentaId,
        fecha: _fecha,
        observado: _observado.text,
        cuidado: _cuidado.text,
      );
      if (!mounted) {
        return;
      }
      await mostrarRegistroGuardado(context, estado: estado);
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
                validator: textoEntre(3, 1000),
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
                validator: textoEntre(3, 1000),
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
      _dosis.text = indicacion?.dosis == null ? '' : numeroCorto(indicacion!.dosis!);
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
      final estado = await Cuidados.instance.registrarAplicacion(
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
      await mostrarRegistroGuardado(context, estado: estado);
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
                if (!estado.hasData) {
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
            // Datos del tratamiento cargados por el veterinario; el trabajador no los modifica.
            if (_indicacion != null) _DatosIndicacion(indicacion: _indicacion!),
            CampoEtiquetado(
              etiqueta: 'Fecha y hora de aplicación *',
              child: _CampoFecha(fecha: _fecha, alPresionar: _elegirFecha),
            ),
            // Solo si la indicación no trae dosis (prevenciones antiguas) se escribe a mano.
            if (_indicacion != null && _indicacion!.dosis == null)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: CampoEtiquetado(
                      etiqueta: 'Dosis *',
                      child: TextFormField(
                        controller: _dosis,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: decoracionCampo(pista: '0'),
                        validator: (texto) {
                          final valor = double.tryParse((texto ?? '').trim().replaceAll(',', '.'));
                          return valor == null || !valor.isFinite || valor <= 0 ? 'Dosis positiva' : null;
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: SelectorUnidad(controlador: _unidad)),
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
              texto: _guardando
                  ? 'Registrando…'
                  : _indicacion?.total != null && !_indicacion!.completa
                  ? 'Registrar aplicación ${_indicacion!.aplicadas + 1} de ${_indicacion!.total}'
                  : 'Registrar aplicación',
              alPresionar: _guardando || (_indicacion?.completa ?? false) ? null : _guardar,
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

// Datos fijos de la indicación y contador de aplicaciones.
class _DatosIndicacion extends StatelessWidget {
  const _DatosIndicacion({required this.indicacion});
  final Indicacion indicacion;

  @override
  Widget build(BuildContext context) {
    final i = indicacion;
    final tema = Theme.of(context).textTheme;
    final total = i.total;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Tarjeta(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(i.nombre, style: tema.titleMedium)),
                ChipEstado(i.contador, tipo: i.completa ? TipoChip.neutro : TipoChip.exito),
              ],
            ),
            if (total != null) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (i.aplicadas / total).clamp(0, 1).toDouble(),
                  minHeight: 8,
                  backgroundColor: colorVerdeSuave,
                  color: colorVerde,
                ),
              ),
            ],
            const SizedBox(height: 10),
            for (final (etiqueta, valor) in [
              ('Dosis', i.dosis == null ? null : '${numeroCorto(i.dosis!)} ${i.unidad ?? ''}'),
              ('Vía', i.via),
              ('Cada', i.frecuencia),
              ('Duración', i.duracion),
              ('Retiro', i.retiro),
            ])
              if (valor != null && valor.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      const Icono('candado', tam: 14, color: colorTextoSuave),
                      const SizedBox(width: 6),
                      Text('$etiqueta: ', style: tema.bodySmall),
                      Expanded(child: Text(valor, style: tema.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
                    ],
                  ),
                ),
            if (i.completa)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: AvisoVetLink(titulo: 'Esta indicación ya tiene todas sus aplicaciones.', advertencia: true),
              ),
          ],
        ),
      ),
    );
  }
}
