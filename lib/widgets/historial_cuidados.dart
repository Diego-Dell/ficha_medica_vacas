import 'package:flutter/material.dart';

import '../logic/cuidados.dart';
import '../models/animal.dart';
import 'vetlink.dart';

/// Aplicaciones y observaciones registradas que permanecen visibles en la ficha del animal.
class HistorialCuidados extends StatefulWidget {
  const HistorialCuidados({super.key, required this.animal});
  final Animal animal;

  @override
  State<HistorialCuidados> createState() => _HistorialCuidadosState();
}

class _HistorialCuidadosState extends State<HistorialCuidados> {
  late Future<(List<AplicacionCuidado>, List<ObservacionCuidado>)> _datos = _cargar();

  // 1. Carga aplicaciones y observaciones del animal.
  Future<(List<AplicacionCuidado>, List<ObservacionCuidado>)> _cargar() async {
    final aplicaciones = await Cuidados.instance.aplicacionesDe(widget.animal);
    List<ObservacionCuidado> observaciones;
    try {
      observaciones = await Cuidados.instance.observacionesDe(widget.animal);
    } on ErrorCuidados {
      observaciones = const [];
    }
    return (aplicaciones, observaciones);
  }

  void _recargar() => setState(() => _datos = _cargar());

  // 2. Corrección: pide los datos nuevos y el motivo; la base guarda el dato anterior.
  Future<void> _corregirAplicacion(AplicacionCuidado a) async {
    final dosis = TextEditingController(text: '${a.dosis}');
    final unidad = TextEditingController(text: a.unidad);
    final observacion = TextEditingController(text: a.observacion ?? '');
    final motivo = TextEditingController();
    final guardar = await _dialogo('Corregir aplicación', [
      _campo('Dosis', dosis, numerico: true),
      _campo('Unidad', unidad),
      _campo('Observación', observacion),
      _campo('Motivo de la corrección *', motivo),
    ]);
    if (guardar != true || !mounted) return;
    try {
      await Cuidados.instance.corregirAplicacion(
        aplicacion: a,
        dosis: double.tryParse(dosis.text.replaceAll(',', '.')) ?? 0,
        unidad: unidad.text,
        observacion: observacion.text,
        motivo: motivo.text,
      );
      if (!mounted) return;
      avisar(context, 'Corrección guardada; se conserva el dato anterior');
      _recargar();
    } on ErrorCuidados catch (e) {
      if (mounted) avisar(context, e.mensaje);
    }
  }

  Future<void> _corregirObservacion(ObservacionCuidado o) async {
    final observado = TextEditingController(text: o.observado);
    final cuidado = TextEditingController(text: o.cuidado);
    final motivo = TextEditingController();
    final guardar = await _dialogo('Corregir observación', [
      _campo('Lo observado', observado),
      _campo('Cuidado realizado', cuidado),
      _campo('Motivo de la corrección *', motivo),
    ]);
    if (guardar != true || !mounted) return;
    try {
      await Cuidados.instance.corregirObservacion(
        observacion: o,
        observado: observado.text,
        cuidado: cuidado.text,
        motivo: motivo.text,
      );
      if (!mounted) return;
      avisar(context, 'Corrección guardada; se conserva el dato anterior');
      _recargar();
    } on ErrorCuidados catch (e) {
      if (mounted) avisar(context, e.mensaje);
    }
  }

  Future<bool?> _dialogo(String titulo, List<Widget> campos) => showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(titulo),
          content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: campos)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Guardar corrección')),
          ],
        ),
      );

  Widget _campo(String etiqueta, TextEditingController control, {bool numerico = false}) => CampoEtiquetado(
        etiqueta: etiqueta,
        child: TextField(
          controller: control,
          decoration: decoracionCampo(),
          keyboardType: numerico ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
        ),
      );

  Widget _fila({required String icono, required String titulo, required List<String> detalles, required VoidCallback alCorregir}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Tarjeta(
          child: Row(
            children: [
              BurbujaIcono(icono),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titulo, style: Theme.of(context).textTheme.labelMedium),
                    for (final d in detalles) Text(d, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              TextButton(onPressed: alCorregir, child: const Text('Corregir')),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => FutureBuilder<(List<AplicacionCuidado>, List<ObservacionCuidado>)>(
        future: _datos,
        builder: (context, estado) {
          if (estado.hasError) {
            return TextButton(
              onPressed: _recargar,
              child: const Text('No se pudieron cargar los cuidados. Reintentar'),
            );
          }
          final datos = estado.data;
          if (datos == null) return const Center(child: CircularProgressIndicator());
          final (aplicaciones, observaciones) = datos;
          if (aplicaciones.isEmpty && observaciones.isEmpty) return const SizedBox.shrink();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (aplicaciones.isNotEmpty) ...[
                Text('Aplicaciones', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                for (final a in aplicaciones)
                  _fila(
                    icono: 'medicamento',
                    titulo: '${a.dosis} ${a.unidad}',
                    detalles: [fechaCorta(a.fecha.toLocal()), if (a.observacion?.isNotEmpty == true) a.observacion!],
                    alCorregir: () => _corregirAplicacion(a),
                  ),
              ],
              if (observaciones.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text('Observaciones', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                for (final o in observaciones)
                  _fila(
                    icono: 'cuidado',
                    titulo: o.observado,
                    detalles: [fechaCorta(o.fecha.toLocal()), 'Cuidado: ${o.cuidado}'],
                    alCorregir: () => _corregirObservacion(o),
                  ),
              ],
            ],
          );
        },
      );
}
