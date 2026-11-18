import 'package:flutter/material.dart';

import '../../logic/fichas.dart';
import '../../logic/granjas.dart';
import '../../models/animal.dart';
import '../../widgets/vetlink.dart';
import 'editar_ficha_screen.dart';
import 'ficha_animal_screen.dart';

class GanadoScreen extends StatefulWidget {
  const GanadoScreen({super.key});

  @override
  State<GanadoScreen> createState() => _GanadoScreenState();
}

class _GanadoScreenState extends State<GanadoScreen> {
  final _busqueda = TextEditingController();
  late Future<List<Animal>> _animales = _cargar();
  Etapa? _etapa;
  bool _conBajas = false;

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  Future<List<Animal>> _cargar() => Fichas.instance.deLaGranja(conBajas: _conBajas);

  /// 1. Vuelve a pedir las fichas a Supabase.
  void _recargar() {
    setState(() {
      _animales = _cargar();
    });
  }

  /// 2. Abre una pantalla y actualiza la lista al volver.
  Future<void> _abrir(Widget pantalla) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => pantalla));
    if (mounted) _recargar();
  }

  /// 3. Filtra por arete o nombre y por etapa sin volver a consultar la base.
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
    void volver() => Navigator.pop(context);

    return PantallaVetLink(
      encabezado: EncabezadoVetLink(granja: granja, alVolver: volver),
      titulo: 'Ganado',
      subtitulo: 'Buscá animales de $granja y revisá su ficha.',
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
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Incluir dados de baja'),
          value: _conBajas,
          onChanged: (valor) {
            _conBajas = valor;
            _recargar();
          },
        ),
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
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '${visibles.length} ${visibles.length == 1 ? 'animal' : 'animales'}',
                    style: tema.labelLarge?.copyWith(color: colorVerdeOscuro, fontWeight: FontWeight.w700),
                  ),
                ),
                if (animales.isEmpty)
                  Text('Todavía no hay fichas en esta granja.', style: tema.bodySmall?.copyWith(color: colorTextoSuave)),
                for (final a in visibles) _TarjetaAnimal(animal: a, alPresionar: () => _abrir(FichaAnimalScreen(animal: a))),
              ],
            );
          },
        ),
        const SizedBox(height: 4),
        if (Fichas.instance.puedeEditar)
          BotonPrincipal(texto: 'Nueva ficha', alPresionar: () => _abrir(const EditarFichaScreen())),
        BotonSecundario(texto: 'Volver', alPresionar: volver),
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
    final datos = [animal.etapa.etiqueta, if (animal.raza != null) animal.raza!, animal.deBaja ? 'Dado de baja' : 'Activo'];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: animal.deBaja ? colorFondo : Colors.white,
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
                Text(
                  datos.join(' · '),
                  style: tema.bodySmall?.copyWith(color: animal.deBaja ? colorRojo : colorTextoSuave),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
