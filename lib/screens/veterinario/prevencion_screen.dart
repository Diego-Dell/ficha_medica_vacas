import 'package:flutter/material.dart';

import '../../logic/granjas.dart';
import '../../logic/tratamientos.dart';
import '../../models/animal.dart';
import '../../models/prevencion.dart';
import '../../widgets/campos_indicacion.dart';
import '../../widgets/selector_animal.dart';
import '../../widgets/vetlink.dart';
import '../ganado/registro_guardado.dart';

class PrevencionScreen extends StatefulWidget {
  const PrevencionScreen({super.key, this.animal, this.control});
  final Animal? animal;
  final Prevencion? control;
  @override
  State<PrevencionScreen> createState() => _PrevencionScreenState();
}

class _PrevencionScreenState extends State<PrevencionScreen> {
  final _formulario = GlobalKey<FormState>(), _nombre = TextEditingController();
  late Animal? _animal = widget.animal;
  String _tipo = 'Vacuna';
  DateTime _fecha = DateUtils.dateOnly(DateTime.now());
  bool _guardando = false;

  @override
  void dispose() {
    _nombre.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_guardando || !_formulario.currentState!.validate()) return;
    if (_animal == null) {
      avisar(context, 'Elegí un animal');
      return;
    }
    setState(() => _guardando = true);
    final error = widget.control == null
        ? await Tratamientos.instance.programar(
            animal: _animal!,
            tipo: _tipo,
            nombre: _nombre.text,
            fecha: _fecha,
          )
        : await Tratamientos.instance.completarControl(
            animal: _animal!,
            prevencion: widget.control!,
            fecha: _fecha,
          );
    if (!mounted) return;
    setState(() => _guardando = false);
    if (error != null) {
      avisar(context, error);
      return;
    }
    await mostrarRegistroGuardado(context);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_guardando,
    child: PantallaVetLink(
      titulo: widget.control == null ? 'Prevención' : 'Completar control',
      subtitulo: widget.control == null
          ? 'Programá vacunas, desparasitación y controles.'
          : 'Registrá la fecha en que se realizó el control.',
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
                  SelectorAnimal(alElegir: (a) => setState(() => _animal = a))
                else
                  Tarjeta(
                    child: Text(
                      widget.animal!.titulo,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                const SizedBox(height: 16),
                if (widget.control == null) ...[
                  CampoEtiquetado(
                    etiqueta: 'Tipo de prevención *',
                    child: DropdownButtonFormField<String>(
                      initialValue: _tipo,
                      isExpanded: true,
                      decoration: decoracionCampo(),
                      items: [
                        for (final t in tiposPrevencion.entries)
                          DropdownMenuItem(value: t.key, child: Text(t.value)),
                      ],
                      onChanged: (v) => setState(() => _tipo = v!),
                    ),
                  ),
                  TextoIndicacion(
                    etiqueta: 'Nombre *',
                    controlador: _nombre,
                    maximo: 200,
                  ),
                ] else ...[
                  Text(
                    widget.control!.nombre,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text('Programado: ${fechaCorta(widget.control!.fecha)}'),
                  const SizedBox(height: 16),
                ],
                FechaIndicacion(
                  etiqueta: widget.control == null
                      ? 'Fecha programada *'
                      : 'Fecha de realización *',
                  fecha: _fecha,
                  minima: widget.control == null
                      ? DateUtils.dateOnly(DateTime.now())
                      : null,
                  maxima: widget.control == null
                      ? null
                      : DateUtils.dateOnly(DateTime.now()),
                  alCambiar: (v) => setState(() => _fecha = v),
                ),
                AvisoVetLink(
                  titulo: widget.control == null
                      ? 'Estado inicial: Pendiente'
                      : 'El control quedará Realizado.',
                  texto: widget.control == null
                      ? 'Las vacunas y desparasitaciones quedan programadas. Los controles se completan desde el historial del animal.'
                      : null,
                ),
                BotonPrincipal(
                  texto: _guardando
                      ? 'Guardando…'
                      : widget.control == null
                      ? 'Programar prevención'
                      : 'Completar control',
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
