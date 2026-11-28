import 'package:flutter/material.dart';

import '../logic/granjas.dart';
import '../logic/tratamientos.dart';
import '../models/animal.dart';
import '../models/miembro.dart';
import '../models/prevencion.dart';
import '../models/tratamiento.dart';
import '../screens/veterinario/prevencion_screen.dart';
import '../screens/veterinario/tratamiento_screen.dart';
import 'vetlink.dart';

class HistorialTratamientos extends StatefulWidget {
  const HistorialTratamientos({super.key, required this.animal});
  final Animal animal;
  @override
  State<HistorialTratamientos> createState() => _HistorialTratamientosState();
}

class _HistorialTratamientosState extends State<HistorialTratamientos> {
  late Future<List<Tratamiento>> _tratamientos = Tratamientos.instance
      .delAnimal(widget.animal.id);
  late Future<List<Prevencion>> _prevenciones = Tratamientos.instance
      .prevencionesDelAnimal(widget.animal.id);

  void _recargar() => setState(() {
    _tratamientos = Tratamientos.instance.delAnimal(widget.animal.id);
    _prevenciones = Tratamientos.instance.prevencionesDelAnimal(
      widget.animal.id,
    );
  });

  @override
  void didUpdateWidget(covariant HistorialTratamientos oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animal != widget.animal) {
      _tratamientos = Tratamientos.instance.delAnimal(widget.animal.id);
      _prevenciones = Tratamientos.instance.prevencionesDelAnimal(
        widget.animal.id,
      );
    }
  }

  Future<void> _abrir(Widget pantalla) async {
    final cambio = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => pantalla),
    );
    if (cambio == true && mounted) _recargar();
  }

  Widget _estado<T>(
    AsyncSnapshot<List<T>> estado,
    Widget Function(List<T>) contenido,
  ) {
    if (estado.connectionState != ConnectionState.done) {
      return const Center(child: CircularProgressIndicator());
    }
    if (estado.hasError) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            estado.error.toString(),
            style: const TextStyle(color: colorRojo),
          ),
          TextButton(onPressed: _recargar, child: const Text('Reintentar')),
        ],
      );
    }
    return contenido(estado.data ?? []);
  }

  @override
  Widget build(BuildContext context) {
    final editar =
        !widget.animal.deBaja && (Granjas.instance.sesionAdministradora || Granjas.instance.rol == RolMiembro.veterinario);
    final tema = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        Text('Tratamientos', style: tema.titleMedium),
        if (editar)
          BotonSecundario(
            texto: 'Indicar tratamiento',
            alPresionar: () => _abrir(TratamientoScreen(animal: widget.animal)),
          ),
        FutureBuilder<List<Tratamiento>>(
          future: _tratamientos,
          builder: (context, estado) => _estado(
            estado,
            (lista) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (lista.isEmpty)
                  const Text('Todavía no hay tratamientos registrados.'),
                for (final t in lista)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Tarjeta(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const BurbujaIcono('tratamiento'),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  t.medicamento,
                                  style: tema.titleMedium,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: ChipEstado(
                              t.estado,
                              tipo: t.vigente
                                  ? TipoChip.exito
                                  : TipoChip.neutro,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text('${t.dosis} ${t.unidad} · ${t.via}'),
                          Text('Frecuencia: ${t.frecuencia}'),
                          Text(
                            'Inicio: ${fechaCorta(t.inicio)} · Duración: ${t.duracion}',
                          ),
                          if (t.retiro?.isNotEmpty == true)
                            Text('Retiro: ${t.retiro}'),
                          if (t.anteriorId != null)
                            const Text('Reemplaza una indicación anterior.'),
                          if (t.fechaFin != null) ...[
                            Text('Cierre: ${fechaCorta(t.fechaFin!)}'),
                            Text('Motivo: ${t.motivoFin ?? 'Sin registrar'}'),
                          ],
                          if (editar && t.vigente)
                            Wrap(
                              spacing: 8,
                              children: [
                                TextButton(
                                  onPressed: () => _abrir(
                                    TratamientoScreen(
                                      animal: widget.animal,
                                      anterior: t,
                                    ),
                                  ),
                                  child: const Text('Modificar'),
                                ),
                                TextButton(
                                  onPressed: () => _abrir(
                                    TratamientoScreen(
                                      animal: widget.animal,
                                      anterior: t,
                                      finalizar: true,
                                    ),
                                  ),
                                  child: const Text('Finalizar'),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text('Prevención', style: tema.titleMedium),
        if (editar)
          BotonSecundario(
            texto: 'Programar prevención',
            alPresionar: () => _abrir(PrevencionScreen(animal: widget.animal)),
          ),
        FutureBuilder<List<Prevencion>>(
          future: _prevenciones,
          builder: (context, estado) => _estado(
            estado,
            (lista) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (lista.isEmpty)
                  const Text('Todavía no hay prevenciones programadas.'),
                for (final p in lista)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Tarjeta(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(p.nombre, style: tema.titleMedium),
                          Text('${p.tipoTexto} · ${fechaCorta(p.fecha)}'),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: ChipEstado(
                              p.estadoTexto,
                              tipo: p.pendiente
                                  ? TipoChip.advertencia
                                  : TipoChip.neutro,
                            ),
                          ),
                          if (p.realizada != null)
                            Text('Realizado: ${fechaCorta(p.realizada!)}'),
                          if (editar && p.pendiente && p.esControl)
                            TextButton(
                              onPressed: () => _abrir(
                                PrevencionScreen(
                                  animal: widget.animal,
                                  control: p,
                                ),
                              ),
                              child: const Text('Completar control'),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        TextButton(
          onPressed: _recargar,
          child: const Text('Actualizar tratamientos y prevención'),
        ),
      ],
    );
  }
}
