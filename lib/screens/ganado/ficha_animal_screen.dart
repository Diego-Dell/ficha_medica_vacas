import 'package:flutter/material.dart';

import '../../logic/fichas.dart';
import '../../logic/granjas.dart';
import '../../models/animal.dart';
import '../../models/miembro.dart';
import '../../widgets/vetlink.dart';
import '../../widgets/historial_cuidados.dart';
import '../../widgets/historial_tratamientos.dart';
import '../inicio_por_rol.dart';
import 'dar_de_baja_screen.dart';
import '../../widgets/historial_clinico.dart';
import 'editar_ficha_screen.dart';

// 1. Ficha del animal: activa, o conservada después de la baja.
class FichaAnimalScreen extends StatefulWidget {
  const FichaAnimalScreen({super.key, required this.animal});

  final Animal animal;

  @override
  State<FichaAnimalScreen> createState() => _FichaAnimalScreenState();
}

class _FichaAnimalScreenState extends State<FichaAnimalScreen> {
  late Animal _animal = widget.animal;

  // Historial clínico y aplicaciones registradas para el animal.
  List<Widget> _registros(Animal animal) => [
    HistorialClinico(animalId: animal.id),
    HistorialTratamientos(animal: animal),
    HistorialCuidados(animal: animal),
  ];

  // 3. Abre editar o dar de baja y vuelve a leer la ficha.
  Future<void> _abrir(Widget pantalla) async {
    final cambio = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => pantalla));
    if (cambio != true || !mounted) return;
    try {
      final actual = await Fichas.instance.porId(_animal.id);
      if (mounted) setState(() => _animal = actual);
    } on Exception {
      if (mounted) avisar(context, 'No se pudo actualizar la ficha');
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    final a = _animal;
    final rol = Granjas.instance.rol;
    final puedeEditar = !a.deBaja;
    final puedeDarDeBaja = !a.deBaja && rol == RolMiembro.dueno;

    Widget dato(String etiqueta, String valor) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: [
              Text(etiqueta, style: tema.bodySmall),
              const SizedBox(width: 12),
              Expanded(
                child: Text(valor, textAlign: TextAlign.right,
                    style: const TextStyle(fontWeight: FontWeight.w600, color: colorVerdeOscuro)),
              ),
            ],
          ),
        );

    return PantallaVetLink(
      encabezado: EncabezadoVetLink(granja: Granjas.instance.actual.nombre, alVolver: () => Navigator.pop(context)),
      titulo: 'Ficha del animal',
      subtitulo: a.deBaja ? 'Ficha conservada después de la baja.' : null,
      children: [
        Tarjeta(
          child: Row(
            children: [
              BurbujaIcono('ganado', tam: 64,
                  fondo: a.deBaja ? colorBorde : colorVerdeSuave, color: a.deBaja ? colorTextoSuave : colorVerde),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.titulo, style: tema.titleLarge),
                    Text([a.etapa.etiqueta, if (a.raza != null) a.raza!].join(' · '), style: tema.bodySmall),
                    const SizedBox(height: 6),
                    a.deBaja
                        ? ChipEstado('De baja · ${fechaCorta(a.fechaBaja!)}', tipo: TipoChip.neutro)
                        : ChipEstado('Activa · ${a.etapa.etiqueta}'),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (puedeEditar || puedeDarDeBaja) ...[
          Row(
            children: [
              if (puedeEditar)
                Expanded(child: BotonSecundario(texto: rol == RolMiembro.veterinario ? 'Editar etapa' : 'Editar ficha', alPresionar: () => _abrir(EditarFichaScreen(animal: a)))),
              if (puedeEditar && puedeDarDeBaja) const SizedBox(width: 12),
              if (puedeDarDeBaja)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: TextButton(
                      style: TextButton.styleFrom(foregroundColor: colorRojo, minimumSize: const Size.fromHeight(52)),
                      onPressed: () => _abrir(DarDeBajaScreen(animal: a)),
                      child: const Text('Dar de baja', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
        ],
        Tarjeta(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(a.deBaja ? 'Baja registrada' : 'Datos generales', style: tema.labelMedium),
              const SizedBox(height: 6),
              if (a.deBaja) ...[
                dato('Fecha', fechaCorta(a.fechaBaja!)),
                dato('Motivo', a.motivoBaja ?? '–'),
              ] else ...[
                dato('Nacimiento', a.nacimiento == null
                    ? 'Sin registrar'
                    : '${fechaCorta(a.nacimiento!)} · ${a.nacimientoEstimado ? 'Estimado' : 'Conocido'}'),
                dato('Raza', a.raza ?? '–'),
                dato('Etapa', a.etapa.etiqueta),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        ..._registros(a),
        if (a.deBaja) ...[
          const AvisoVetLink(
            titulo: 'Esta ficha no admite nuevos eventos.',
            texto: 'Su historial queda disponible para consulta.',
            advertencia: true,
          ),
          BotonSecundario(
            texto: 'Volver a la granja',
            alPresionar: () => Navigator.popUntil(context, (ruta) => ruta.settings.name == InicioPorRol.ruta || ruta.isFirst),
          ),
        ],
      ],
    );
  }
}
