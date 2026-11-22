import 'package:flutter/material.dart';

import '../../logic/fichas.dart';
import '../../logic/granjas.dart';
import '../../models/animal.dart';
import '../../widgets/vetlink.dart';
import 'dar_de_baja_screen.dart';
import 'editar_ficha_screen.dart';

class FichaAnimalScreen extends StatefulWidget {
  const FichaAnimalScreen({super.key, required this.animal});

  final Animal animal;

  @override
  State<FichaAnimalScreen> createState() => _FichaAnimalScreenState();
}

class _FichaAnimalScreenState extends State<FichaAnimalScreen> {
  late Animal _animal = widget.animal;

  /// 1. Registros del animal: aquí Clínica, Tratamientos y Cuidados agregan su OpcionPanel.
  /// Reciben el animal para abrir su pantalla con él ya elegido; los antecedentes se consultan
  /// siempre, y los registros nuevos solo si el animal no está dado de baja.
  List<Widget> _registros(Animal animal) => const [];

  /// 2. Abre una pantalla y, si guardó cambios, vuelve a leer la ficha.
  Future<void> _abrir(Widget pantalla) async {
    final cambio = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => pantalla));
    if (cambio != true || !mounted) return;
    try {
      final actual = await Fichas.instance.porId(_animal.id);
      if (mounted) setState(() => _animal = actual);
    } on Exception {
      if (mounted) avisar(context, 'No se pudo actualizar la ficha. Volvé a abrirla');
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    final a = _animal;
    void volver() => Navigator.pop(context);
    final nacimiento = a.nacimiento == null
        ? 'Sin registrar'
        : '${fechaCorta(a.nacimiento!)}${a.nacimientoEstimado ? ' (estimada)' : ''}';

    return PantallaVetLink(
      encabezado: EncabezadoVetLink(granja: Granjas.instance.actual.nombre, alVolver: volver),
      titulo: a.titulo,
      subtitulo: 'Ficha y datos generales del animal.',
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: a.deBaja ? colorAmbarFondo : colorVerdeSuave,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                a.deBaja ? 'Dado de baja el ${fechaCorta(a.fechaBaja!)}' : 'Activo · ${a.etapa.etiqueta}',
                style: tema.labelLarge?.copyWith(
                  color: a.deBaja ? colorAmbarTexto : colorVerdeOscuro,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (a.deBaja) ...[
                const SizedBox(height: 4),
                Text(
                  'Motivo: ${a.motivoBaja}. La ficha y su historial se conservan, pero no admite nuevos eventos.',
                  style: tema.bodySmall?.copyWith(color: colorAmbarTexto),
                ),
              ],
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: colorBorde),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (etiqueta, valor) in [
                ('Identificación', a.arete),
                ('Nombre', a.nombre ?? 'Sin nombre'),
                ('Raza', a.raza ?? 'Sin registrar'),
                ('Etapa', a.etapa.etiqueta),
                ('Nacimiento', nacimiento),
              ])
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 110,
                        child: Text(etiqueta, style: tema.bodySmall?.copyWith(color: colorTextoSuave)),
                      ),
                      Expanded(child: Text(valor, style: tema.bodyMedium?.copyWith(color: colorVerdeOscuro))),
                    ],
                  ),
                ),
            ],
          ),
        ),
        if (_registros(a).isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Registros del animal',
              style: tema.labelLarge?.copyWith(color: colorVerdeOscuro, fontWeight: FontWeight.w700),
            ),
          ),
          ..._registros(a),
        ],
        if (!a.deBaja && Fichas.instance.puedeEditar)
          BotonPrincipal(texto: 'Editar datos', alPresionar: () => _abrir(EditarFichaScreen(animal: a))),
        if (!a.deBaja && Fichas.instance.puedeDarDeBaja)
          BotonSecundario(texto: 'Dar de baja', alPresionar: () => _abrir(DarDeBajaScreen(animal: a))),
        BotonSecundario(texto: 'Volver', alPresionar: volver),
      ],
    );
  }
}
