import 'package:flutter/material.dart';

import '../../logic/granjas.dart';
import '../../models/animal.dart';
import '../../widgets/vetlink.dart';

class DarDeBajaScreen extends StatefulWidget {
  const DarDeBajaScreen({super.key});

  @override
  State<DarDeBajaScreen> createState() => _DarDeBajaScreenState();
}

class _DarDeBajaScreenState extends State<DarDeBajaScreen> {
  final _form = GlobalKey<FormState>();
  final _motivo = TextEditingController();
  late Future<List<Animal>> _animales = Granjas.instance.animalesActivos();
  Animal? _animal;
  DateTime _fecha = DateUtils.dateOnly(DateTime.now());
  bool _enviando = false;

  @override
  void dispose() {
    _motivo.dispose();
    super.dispose();
  }

  /// 1. Vuelve a pedir los animales al servidor.
  void _recargar() {
    setState(() {
      _animales = Granjas.instance.animalesActivos();
    });
  }

  /// 2. Abre el calendario sin permitir fechas futuras.
  Future<void> _elegirFecha() async {
    final hoy = DateUtils.dateOnly(DateTime.now());
    final elegida = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(hoy.year - 10),
      lastDate: hoy,
    );
    if (elegida != null) setState(() => _fecha = elegida);
  }

  /// 3. Registra la baja del animal elegido.
  Future<void> _confirmar(Animal animal) async {
    // 3.1. Valida el formulario y evita envíos dobles.
    if (_enviando || !_form.currentState!.validate()) return;
    setState(() => _enviando = true);

    // 3.2. Guarda la fecha y el motivo en el servidor.
    final error = await Granjas.instance.darDeBaja(animal, _fecha, _motivo.text.trim());
    if (!mounted) return;
    setState(() => _enviando = false);

    // 3.3. Muestra el error o avisa el resultado y vuelve a Mi granja.
    if (error != null) {
      avisar(context, error);
      return;
    }
    avisar(context, '${animal.titulo} se dio de baja. Su ficha y su historial se conservan');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final granja = Granjas.instance.actual.nombre;
    final tema = Theme.of(context).textTheme;
    void volver() => Navigator.pop(context);

    return PantallaVetLink(
      encabezado: EncabezadoVetLink(granja: granja, alVolver: volver),
      barraInferior: BarraVetLink(alVolver: volver),
      titulo: 'Dar de baja',
      subtitulo: 'La ficha y el historial se conservarán.',
      children: [
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
            if (animales.isEmpty) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text('No hay animales para dar de baja.', style: tema.bodyMedium?.copyWith(color: colorTextoSuave)),
              );
            }
            final animal = _animal ?? animales.first;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (animales.length > 1)
                  CampoEtiquetado(
                    etiqueta: 'Animal *',
                    child: DropdownButtonFormField<String>(
                      initialValue: animal.id,
                      isExpanded: true,
                      decoration: decoracionCampo(),
                      items: [
                        for (final a in animales) DropdownMenuItem(value: a.id, child: Text(a.titulo)),
                      ],
                      onChanged: (id) => setState(() => _animal = animales.firstWhere((a) => a.id == id)),
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(color: colorVerdeSuave, borderRadius: BorderRadius.circular(10)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        animal.titulo,
                        style: tema.titleSmall?.copyWith(color: colorVerdeOscuro, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [animal.categoria, if (animal.raza != null) animal.raza!, granja].join(' · '),
                        style: tema.bodySmall?.copyWith(color: colorTextoSuave),
                      ),
                    ],
                  ),
                ),
                Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      CampoEtiquetado(
                        etiqueta: 'Fecha de baja *',
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: _elegirFecha,
                          child: InputDecorator(decoration: decoracionCampo(), child: Text(fechaCorta(_fecha))),
                        ),
                      ),
                      CampoEtiquetado(
                        etiqueta: 'Motivo *',
                        child: TextFormField(
                          controller: _motivo,
                          decoration: decoracionCampo(pista: 'Venta del animal'),
                          textCapitalization: TextCapitalization.sentences,
                          maxLines: 3,
                          validator: requerido,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(color: colorAmbarFondo, borderRadius: BorderRadius.circular(10)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Revisá antes de confirmar',
                        style: tema.labelLarge?.copyWith(color: colorAmbarTexto, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'El animal dado de baja no admitirá nuevos eventos.',
                        style: tema.bodySmall?.copyWith(color: colorAmbarTexto),
                      ),
                    ],
                  ),
                ),
                BotonPrincipal(
                  texto: _enviando ? 'Confirmando...' : 'Confirmar baja',
                  color: colorRojo,
                  alPresionar: _enviando ? null : () => _confirmar(animal),
                ),
              ],
            );
          },
        ),
        BotonSecundario(texto: 'Volver', alPresionar: volver),
      ],
    );
  }
}
