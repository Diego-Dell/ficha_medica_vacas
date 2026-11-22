import 'package:flutter/material.dart';

import '../../logic/fichas.dart';
import '../../logic/granjas.dart';
import '../../models/animal.dart';
import '../../models/miembro.dart';
import '../../widgets/vetlink.dart';
import 'editar_ficha_screen.dart';
import 'ficha_animal_screen.dart';

// 1. Pestaña Ganado: buscar, filtrar por etapa y crear fichas.
class GanadoScreen extends StatefulWidget {
  const GanadoScreen({super.key, this.enPestana = false});

  // 2. Dentro de la barra inferior no lleva botón de volver.
  final bool enPestana;

  @override
  State<GanadoScreen> createState() => _GanadoScreenState();
}

class _GanadoScreenState extends State<GanadoScreen> {
  final _busqueda = TextEditingController();
  // 3. Incluye las bajas: su ficha sigue consultable.
  late Future<List<Animal>> _animales = Fichas.instance.deLaGranja(conBajas: true);
  Etapa? _etapa;

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  void _recargar() {
    setState(() {
      _animales = Fichas.instance.deLaGranja(conBajas: true);
    });
  }

  Future<void> _abrir(Widget pantalla) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => pantalla));
    if (mounted) _recargar();
  }

  // 4. Filtra por identificación o nombre y por etapa.
  List<Animal> _filtrar(List<Animal> animales) {
    final texto = _busqueda.text.trim().toLowerCase();
    return [
      for (final a in animales)
        if ((_etapa == null || a.etapa == _etapa) &&
            (texto.isEmpty || a.arete.toLowerCase().contains(texto) || (a.nombre ?? '').toLowerCase().contains(texto)))
          a,
    ];
  }

  Widget _filtro(String texto, Etapa? etapa) {
    final activo = _etapa == etapa;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(texto),
        selected: activo,
        showCheckmark: false,
        selectedColor: colorVerde,
        backgroundColor: colorSuperficie,
        side: BorderSide(color: activo ? colorVerde : colorBorde),
        shape: const StadiumBorder(),
        labelStyle: TextStyle(fontWeight: FontWeight.w600, color: activo ? Colors.white : colorTextoSuave),
        onSelected: (_) => setState(() => _etapa = etapa),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    // 5. El veterinario consulta; dueño y trabajador también crean fichas.
    final puedeCrear = Granjas.instance.rol != RolMiembro.veterinario;

    return PantallaVetLink(
      encabezado: EncabezadoVetLink(
        granja: Granjas.instance.actual.nombre,
        alVolver: widget.enPestana ? null : () => Navigator.pop(context),
      ),
      titulo: 'Ganado',
      botonFlotante: puedeCrear
          ? FloatingActionButton.extended(
              onPressed: () => _abrir(const EditarFichaScreen()),
              backgroundColor: colorVerde,
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
              icon: const Icono('agregar', color: Colors.white, tam: 20),
              label: const Text('Nueva ficha', style: TextStyle(fontWeight: FontWeight.w600)),
            )
          : null,
      children: [
        TextField(
          controller: _busqueda,
          decoration: decoracionCampo(pista: 'Buscar por identificación o nombre', icono: 'buscar'),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [_filtro('Todas', null), for (final e in Etapa.values) _filtro(e.etiqueta, e)]),
        ),
        const SizedBox(height: 12),
        FutureBuilder<List<Animal>>(
          future: _animales,
          builder: (context, estado) {
            if (estado.hasError) {
              return TextButton(
                style: TextButton.styleFrom(foregroundColor: colorRojo),
                onPressed: _recargar,
                child: const Text('No se pudieron cargar los animales. Reintentar'),
              );
            }
            final animales = estado.data;
            if (animales == null) {
              return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
            }
            if (animales.isEmpty) return const _SinAnimales();
            final visibles = _filtrar(animales);
            final bajas = animales.where((a) => a.deBaja).length;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('${animales.length - bajas} animales${bajas > 0 ? ' · $bajas de baja' : ''}', style: tema.bodySmall),
                const SizedBox(height: 12),
                if (visibles.isEmpty) Text('Sin resultados.', style: tema.bodySmall),
                for (final a in visibles)
                  _TarjetaAnimal(animal: a, alPresionar: () => _abrir(FichaAnimalScreen(animal: a))),
              ],
            );
          },
        ),
      ],
    );
  }
}

// 6. Estado vacío: todavía no hay animales.
class _SinAnimales extends StatelessWidget {
  const _SinAnimales();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          children: [
            const BurbujaIcono('ganado', tam: 80),
            const SizedBox(height: 16),
            Text('Todavía no hay animales', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text('Creá la primera ficha para empezar el seguimiento.',
                textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      );
}

class _TarjetaAnimal extends StatelessWidget {
  const _TarjetaAnimal({required this.animal, required this.alPresionar});

  final Animal animal;
  final VoidCallback alPresionar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    final datos = [animal.etapa.etiqueta, if (animal.raza != null) animal.raza!];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Tarjeta(
        alPresionar: alPresionar,
        child: Row(
          children: [
            BurbujaIcono('ganado',
                fondo: animal.deBaja ? colorBorde : colorVerdeSuave,
                color: animal.deBaja ? colorTextoSuave : colorVerde),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(animal.titulo, style: tema.titleMedium?.copyWith(
                      fontSize: 15, color: animal.deBaja ? colorTextoSuave : colorVerdeOscuro)),
                  Text(datos.join(' · '), style: tema.bodySmall),
                ],
              ),
            ),
            if (animal.deBaja) const ChipEstado('De baja', tipo: TipoChip.neutro) else const ChipEstado('Activa'),
            const SizedBox(width: 4),
            const Icono('flecha', color: colorTextoSuave, tam: 18),
          ],
        ),
      ),
    );
  }
}
