import 'package:flutter/material.dart';

import '../../logic/clinica.dart';
import '../../logic/dosis.dart';
import '../../logic/granjas.dart';
import '../../logic/sincronizacion.dart';
import '../../logic/tratamientos.dart';
import '../../models/animal.dart';
import '../../models/registro_clinico.dart';
import '../../models/tratamiento.dart';
import '../../widgets/campos_indicacion.dart';
import '../../widgets/selector_animal.dart';
import '../../widgets/vetlink.dart';
import '../ganado/registro_guardado.dart';

class TratamientoScreen extends StatefulWidget {
  const TratamientoScreen({
    super.key,
    this.animal,
    this.anterior,
    this.finalizar = false,
  });
  final Animal? animal;
  final Tratamiento? anterior;
  final bool finalizar;
  @override
  State<TratamientoScreen> createState() => _TratamientoScreenState();
}

class _TratamientoScreenState extends State<TratamientoScreen> {
  final _formulario = GlobalKey<FormState>();
  final _medicamento = TextEditingController(),
      _dosis = TextEditingController(),
      _unidad = TextEditingController(),
      _via = TextEditingController(),
      _frecuencia = TextEditingController(),
      _duracion = TextEditingController(),
      _retiro = TextEditingController(),
      _motivo = TextEditingController();
  Animal? _animal;
  RegistroClinico? _atencion;
  Future<List<RegistroClinico>>? _atenciones;
  DateTime _inicio = DateUtils.dateOnly(DateTime.now()),
      _fin = DateUtils.dateOnly(DateTime.now());
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    final anterior = widget.anterior;
    if (anterior != null) {
      _medicamento.text = anterior.medicamento;
      _dosis.text = '${anterior.dosis}';
      _unidad.text = anterior.unidad;
      _via.text = anterior.via;
      // Cada y Duración se editan como números (horas y días).
      _frecuencia.text = '${numeroDe(anterior.frecuencia) ?? ''}';
      _duracion.text = '${numeroDe(anterior.duracion) ?? ''}';
      _retiro.text = anterior.retiro ?? '';
    }
    if (widget.animal != null) _elegir(widget.animal!);
  }

  void _elegir(Animal animal) {
    _animal = animal;
    _atencion = null;
    _atenciones = Clinica.instance
        .atencionesDelAnimal(animal.id)
        .then((registros) => registros.where((r) => !r.anulado).toList());
  }

  @override
  void dispose() {
    for (final c in [
      _medicamento,
      _dosis,
      _unidad,
      _via,
      _frecuencia,
      _duracion,
      _retiro,
      _motivo,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _selectorAtencion() => FutureBuilder<List<RegistroClinico>>(
    future: _atenciones,
    builder: (context, estado) {
      if (_animal == null) {
        return const AvisoVetLink(
          titulo: 'Elegí un animal para consultar sus atenciones.',
        );
      }
      if (estado.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (estado.hasError) {
        return TextButton(
          onPressed: () => setState(() => _elegir(_animal!)),
          child: const Text('No se pudieron cargar las atenciones. Reintentar'),
        );
      }
      final lista = estado.data ?? [];
      final anterior = widget.anterior;
      if (anterior != null) {
        _atencion = lista.where((a) => a.id == anterior.atencionId).firstOrNull;
      }
      if (lista.isEmpty || (anterior != null && _atencion == null)) {
        // F8: si la atención quedó guardada sin conexión, se avisa que falta sincronizarla.
        return FutureBuilder<int>(
          future: Sincronizacion.instance.atencionesSinEnviar(_animal!.id),
          builder: (context, pendientes) => AvisoVetLink(
            titulo: 'No hay una atención clínica vigente para esta indicación.',
            texto: (pendientes.data ?? 0) > 0
                ? 'Hay una atención de este animal guardada en el celular. Sincronizala desde Perfil › Sincronización y volvé a intentar.'
                : 'Necesitás una atención clínica registrada para este animal.',
            advertencia: true,
          ),
        );
      }
      return CampoEtiquetado(
        etiqueta: 'Atención clínica *',
        child: DropdownButtonFormField<String>(
          key: ValueKey('atencion:${_animal!.id}'),
          initialValue: _atencion?.id,
          isExpanded: true,
          decoration: decoracionCampo(pista: 'Elegir atención del animal'),
          items: [
            for (final a in lista)
              DropdownMenuItem(
                value: a.id,
                child: Text(
                  '${fechaCorta(a.fecha)} · ${a.titulo}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: anterior != null
              ? null
              : (id) => setState(
                  () => _atencion = lista.firstWhere((a) => a.id == id),
                ),
          validator: (_) =>
              _atencion == null ? 'Elegí una atención clínica' : null,
        ),
      );
    },
  );

  Future<void> _guardar() async {
    if (_guardando || !_formulario.currentState!.validate()) return;
    if (_animal == null) {
      avisar(context, 'Elegí un animal');
      return;
    }
    if (!widget.finalizar && _atencion == null) {
      avisar(context, 'Elegí una atención clínica');
      return;
    }
    setState(() => _guardando = true);
    final error = widget.finalizar
        ? await Tratamientos.instance.finalizar(
            animal: _animal!,
            tratamiento: widget.anterior!,
            fecha: _fin,
            motivo: _motivo.text,
          )
        : await Tratamientos.instance.guardar(
            animal: _animal!,
            atencion: _atencion!,
            anterior: widget.anterior,
            fechaFin: widget.anterior == null ? null : _fin,
            motivoFin: widget.anterior == null ? null : _motivo.text,
            indicacion: IndicacionTratamiento(
              medicamento: _medicamento.text,
              dosis: double.parse(_dosis.text.trim().replaceAll(',', '.')),
              unidad: _unidad.text,
              via: _via.text,
              frecuencia: textoCada(int.parse(_frecuencia.text)),
              inicio: _inicio,
              duracion: textoDuracion(int.parse(_duracion.text)),
              retiro: _retiro.text,
            ),
          );
    if (!mounted) return;
    setState(() => _guardando = false);
    if (error != null) {
      avisar(context, error);
      return;
    }
    await mostrarRegistroGuardado(
      context,
      estado: widget.anterior == null ? Sincronizacion.instance.ultimoEstado : null,
    );
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_guardando,
    child: PantallaVetLink(
      titulo: widget.finalizar
          ? 'Finalizar tratamiento'
          : widget.anterior != null
          ? 'Modificar tratamiento'
          : 'Tratamiento',
      subtitulo: widget.finalizar
          ? 'Registrá el cierre de la indicación.'
          : 'Indicá el tratamiento para una atención del animal.',
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
                if (widget.animal == null)
                  SelectorAnimal(alElegir: (a) => setState(() => _elegir(a)))
                else
                  Tarjeta(
                    child: Text(
                      widget.animal!.titulo,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                const SizedBox(height: 16),
                if (widget.anterior != null) ...[
                  AvisoVetLink(
                    titulo: 'La indicación anterior se conserva.',
                    texto: widget.finalizar
                        ? 'Se guardarán la fecha y el motivo de cierre.'
                        : 'Al guardar, se cerrará la anterior y se creará una nueva indicación.',
                  ),
                  FechaIndicacion(
                    etiqueta: 'Fecha de cierre *',
                    fecha: _fin,
                    maxima: DateUtils.dateOnly(DateTime.now()),
                    alCambiar: (v) => setState(() => _fin = v),
                  ),
                  TextoIndicacion(
                    etiqueta: 'Motivo de cierre *',
                    controlador: _motivo,
                    maximo: 500,
                    lineas: 2,
                  ),
                ],
                if (!widget.finalizar) ...[
                  _selectorAtencion(),
                  TextoIndicacion(
                    etiqueta: 'Medicamento *',
                    controlador: _medicamento,
                    maximo: 200,
                  ),
                  TextoIndicacion(
                    etiqueta: 'Dosis *',
                    controlador: _dosis,
                    numerico: true,
                    maximo: 20,
                    validar: (v) {
                      final dosis = double.tryParse(
                        (v ?? '').trim().replaceAll(',', '.'),
                      );
                      return dosis == null ||
                              !dosis.isFinite ||
                              dosis < .001 ||
                              dosis > 9999999.999
                          ? 'Ingresá una dosis positiva válida'
                          : null;
                    },
                  ),
                  SelectorUnidad(controlador: _unidad),
                  TextoIndicacion(
                    etiqueta: 'Vía de administración *',
                    controlador: _via,
                    maximo: 60,
                  ),
                  EnteroIndicacion(
                    etiqueta: 'Cada *',
                    controlador: _frecuencia,
                    sufijo: 'horas',
                    maximo: 720,
                  ),
                  FechaIndicacion(
                    etiqueta: 'Inicio *',
                    fecha: _inicio,
                    alCambiar: (v) => setState(() => _inicio = v),
                  ),
                  EnteroIndicacion(
                    etiqueta: 'Duración *',
                    controlador: _duracion,
                    sufijo: 'días',
                    maximo: 365,
                  ),
                  // Total de dosis calculado; es el que verá el trabajador al aplicar.
                  ListenableBuilder(
                    listenable: Listenable.merge([_frecuencia, _duracion, _dosis, _unidad]),
                    builder: (context, _) {
                      final cada = int.tryParse(_frecuencia.text);
                      final dias = int.tryParse(_duracion.text);
                      final total = cada == null || dias == null
                          ? null
                          : totalDosis(textoCada(cada), textoDuracion(dias));
                      return AvisoVetLink(
                        titulo: total == null
                            ? 'Total de dosis: completá Cada y Duración'
                            : 'Total de dosis: $total',
                        texto: total == null || _dosis.text.trim().isEmpty
                            ? null
                            : '${_dosis.text.trim()} ${_unidad.text} por aplicación',
                      );
                    },
                  ),
                  TextoIndicacion(
                    etiqueta: 'Retiro (si corresponde)',
                    controlador: _retiro,
                    maximo: 500,
                    obligatorio: false,
                    lineas: 2,
                    pista: 'Indicaciones de retiro de leche o carne',
                  ),
                ],
                BotonPrincipal(
                  texto: _guardando
                      ? 'Guardando…'
                      : widget.finalizar
                      ? 'Finalizar tratamiento'
                      : 'Guardar tratamiento',
                  alPresionar: _guardando ? null : _guardar,
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
