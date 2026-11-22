import 'package:flutter/material.dart';

import '../../logic/fichas.dart';
import '../../logic/granjas.dart';
import '../../models/animal.dart';
import '../../widgets/vetlink.dart';
import 'ficha_animal_screen.dart';

// 1. "Consulta y supervisión" del prototipo (05 · Vistas compartidas).
class GanadoScreen extends StatefulWidget {
  const GanadoScreen({super.key});

  @override
  State<GanadoScreen> createState() => _GanadoScreenState();
}

class _GanadoScreenState extends State<GanadoScreen> {
  final _busqueda = TextEditingController();
  // 2. Incluye las bajas: su ficha sigue consultable.
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

  Future<void> _abrir(Animal animal) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => FichaAnimalScreen(animal: animal)));
    if (mounted) _recargar();
  }

  // 3. Filtra por identificación o nombre y por etapa.
  List<Animal> _filtrar(List<Animal> animales) {
    final texto = _busqueda.text.trim().toLowerCase();
    return [
      for (final a in animales)
        if ((_etapa == null || a.etapa == _etapa) &&
            (texto.isEmpty || a.arete.toLowerCase().contains(texto) || (a.nombre ?? '').toLowerCase().contains(texto)))
          a,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final granja = Granjas.instance.actual.nombre;
    final tema = Theme.of(context).textTheme;
    final etiqueta = tema.labelMedium?.copyWith(color: colorVerdeOscuro);

    return PantallaVetLink(
      encabezado: EncabezadoVetLink(granja: granja, alVolver: () => Navigator.pop(context)),
      titulo: 'Consulta y supervisión',
      subtitulo: 'Buscá animales y revisá su seguimiento.',
      children: [
        CampoEtiquetado(
          etiqueta: 'Identificación o nombre',
          child: TextField(
            controller: _busqueda,
            decoration: decoracionCampo(pista: 'Buscar animal'),
            onChanged: (_) => setState(() {}),
          ),
        ),
        CampoEtiquetado(
          etiqueta: 'Etapa',
          child: DropdownButtonFormField<Etapa?>(
            initialValue: _etapa,
            decoration: decoracionCampo(),
            items: [
              const DropdownMenuItem(value: null, child: Text('Todas')),
              for (final e in Etapa.values) DropdownMenuItem(value: e, child: Text(e.etiqueta)),
            ],
            onChanged: (etapa) => setState(() => _etapa = etapa),
          ),
        ),
        Text('Resultados:', style: tema.labelLarge?.copyWith(color: colorVerde, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text('Animales', style: etiqueta),
        const SizedBox(height: 8),
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
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final visibles = _filtrar(animales);
            if (visibles.isEmpty) {
              return Text('Sin resultados.', style: tema.bodySmall?.copyWith(color: colorTextoSuave));
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [for (final a in visibles) _TarjetaAnimal(animal: a, alPresionar: () => _abrir(a))],
            );
          },
        ),
      ],
    );
  }
}

class _TarjetaAnimal extends StatelessWidget {
  const _TarjetaAnimal({required this.animal, required this.alPresionar});

  final Animal animal;
  final VoidCallback alPresionar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    final datos = [animal.etapa.etiqueta, if (animal.raza != null) animal.raza!, if (animal.deBaja) 'De baja'];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: colorBorde),
          borderRadius: BorderRadius.circular(10),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: alPresionar,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${animal.titulo}  ›',
                  style: tema.titleSmall?.copyWith(color: colorVerdeOscuro, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(datos.join(' · '), style: tema.bodySmall?.copyWith(color: colorTextoSuave)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
