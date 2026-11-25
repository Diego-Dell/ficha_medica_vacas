import 'package:flutter/material.dart';

import '../../logic/consulta_ganado.dart';
import '../../logic/fichas.dart';
import '../../logic/granjas.dart';
import '../../logic/tratamientos.dart';
import '../../models/miembro.dart';
import '../../widgets/vetlink.dart';
import '../trabajador/registro_cuidados_screen.dart';
import '../veterinario/prevencion_screen.dart';
import 'ficha_animal_screen.dart';

/// Vacunas y controles pendientes de la granja seleccionada.
class AvisosScreen extends StatefulWidget {
  const AvisosScreen({super.key, this.enPestana = false});

  final bool enPestana;

  @override
  State<AvisosScreen> createState() => _AvisosScreenState();
}

class _AvisosScreenState extends State<AvisosScreen> {
  late Future<List<AvisoGanado>> _avisos = _cargar();
  bool? _soloVencidos;

  Future<List<AvisoGanado>> _cargar() async {
    final animales = await Fichas.instance.activos();
    final prevenciones = await Tratamientos.instance.prevencionesDeAnimales(animales);
    return avisosDeGranja(animales, prevenciones);
  }

  void _recargar() => setState(() => _avisos = _cargar());

  Future<void> _abrir(Widget pantalla) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => pantalla));
    if (mounted) _recargar();
  }

  Widget _filtro(String texto, bool? vencidos) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(texto),
          selected: _soloVencidos == vencidos,
          showCheckmark: false,
          selectedColor: colorVerde,
          backgroundColor: colorSuperficie,
          side: BorderSide(color: _soloVencidos == vencidos ? colorVerde : colorBorde),
          labelStyle: TextStyle(
            color: _soloVencidos == vencidos ? Colors.white : colorTextoSuave,
            fontWeight: FontWeight.w600,
          ),
          onSelected: (_) => setState(() => _soloVencidos = vencidos),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final puedeCompletarControl = Granjas.instance.sesionAdministradora ||
        Granjas.instance.rol == RolMiembro.veterinario;
    final puedeAplicar = puedeCompletarControl ||
        Granjas.instance.rol == RolMiembro.trabajador;

    return PantallaVetLink(
      encabezado: EncabezadoVetLink(
        granja: Granjas.instance.actual.nombre,
        alVolver: widget.enPestana ? null : () => Navigator.pop(context),
      ),
      titulo: 'Avisos',
      subtitulo: 'Vacunas y controles pendientes de esta granja.',
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _filtro('Todos', null),
            _filtro('Pendientes', false),
            _filtro('Vencidos', true),
          ]),
        ),
        TextButton.icon(
          onPressed: _recargar,
          icon: const Icon(Icons.refresh),
          label: const Text('Actualizar avisos'),
        ),
        FutureBuilder<List<AvisoGanado>>(
          future: _avisos,
          builder: (context, estado) {
            if (estado.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (estado.hasError) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('No se pudieron cargar los avisos.'),
                  TextButton(onPressed: _recargar, child: const Text('Reintentar')),
                ],
              );
            }
            final avisos = estado.data!;
            final vencidos = avisos.where((a) => a.vencido).length;
            final visibles = avisos.where((a) =>
                _soloVencidos == null || a.vencido == _soloVencidos).toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('${visibles.length} coincidencias · $vencidos vencidos de ${avisos.length} avisos',
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 12),
                if (visibles.isEmpty)
                  const Text('No hay avisos para este filtro.'),
                for (final aviso in visibles)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Tarjeta(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(children: [
                            const BurbujaIcono('avisos'),
                            const SizedBox(width: 12),
                            Expanded(child: Text(aviso.animal.titulo,
                                style: Theme.of(context).textTheme.titleMedium)),
                          ]),
                          const SizedBox(height: 8),
                          Text('${aviso.prevencion.tipoTexto} · ${aviso.prevencion.nombre}'),
                          Text('Programado: ${fechaCorta(aviso.prevencion.fecha)}'),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: ChipEstado(aviso.vencido ? 'Vencido' : 'Pendiente',
                                tipo: TipoChip.advertencia),
                          ),
                          Wrap(spacing: 8, children: [
                            TextButton(
                              onPressed: () => _abrir(FichaAnimalScreen(animal: aviso.animal)),
                              child: const Text('Ver ficha'),
                            ),
                            if (aviso.prevencion.esControl && puedeCompletarControl)
                              TextButton(
                                onPressed: () => _abrir(PrevencionScreen(
                                  animal: aviso.animal, control: aviso.prevencion)),
                                child: const Text('Completar control'),
                              ),
                            if (!aviso.prevencion.esControl && puedeAplicar)
                              TextButton(
                                onPressed: () => _abrir(AplicacionScreen(animal: aviso.animal)),
                                child: const Text('Registrar aplicación'),
                              ),
                          ]),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
