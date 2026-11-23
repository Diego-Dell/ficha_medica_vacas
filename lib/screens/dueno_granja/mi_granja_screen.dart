import 'package:flutter/material.dart';

import '../../logic/fichas.dart';
import '../../logic/granjas.dart';
import '../../models/animal.dart';
import '../../models/miembro.dart';
import '../../widgets/panel_rol.dart';
import '../../widgets/vetlink.dart';
import 'datos_granja_screen.dart';
import 'miembros_screen.dart';
import 'registrar_otra_granja_screen.dart';

// 1. Inicio del dueño: resumen, ganado por etapa y equipo.
class MiGranjaScreen extends StatefulWidget {
  const MiGranjaScreen({super.key});

  @override
  State<MiGranjaScreen> createState() => _MiGranjaScreenState();
}

class _MiGranjaScreenState extends State<MiGranjaScreen> {
  late final Future<List<Animal>> _ganado = Fichas.instance.activos();
  late final Future<List<Miembro>> _equipo = Granjas.instance.miembros();

  void _abrir(Widget pantalla) => Navigator.push(context, MaterialPageRoute(builder: (_) => pantalla));

  @override
  Widget build(BuildContext context) {
    final datos = Granjas.instance;
    return PanelRol(
      rol: datos.rol.etiqueta,
      granja: datos.actual.nombre,
      alRegistrarGranja: () => _abrir(const RegistrarOtraGranjaScreen()),
      children: [
        FutureBuilder<List<Animal>>(
          future: _ganado,
          builder: (context, ganado) => FutureBuilder<List<Miembro>>(
            future: _equipo,
            builder: (context, equipo) => _Resumen(animales: ganado.data?.length, miembros: equipo.data?.length),
          ),
        ),
        const SizedBox(height: 16),
        FutureBuilder<List<Animal>>(
          future: _ganado,
          builder: (context, ganado) => ganado.hasData ? _PorEtapa(ganado.data!) : const SizedBox.shrink(),
        ),
        if (datos.rol == RolMiembro.dueno)
          FutureBuilder<List<Miembro>>(
            future: _equipo,
            builder: (context, equipo) => OpcionPanel(
              titulo: 'Equipo',
              detalle: equipo.hasData ? '${equipo.data!.length} miembros' : null,
              icono: 'miembros',
              alPresionar: () => _abrir(const MiembrosScreen()),
            ),
          ),
        // 4. Única entrada para actualizar el RUNSA.
        if (datos.rol == RolMiembro.dueno)
          OpcionPanel(
            titulo: 'Datos de la granja',
            detalle: 'RUNSA ${datos.actual.runsa}',
            icono: 'granja',
            alPresionar: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const DatosGranjaScreen()));
              if (mounted) setState(() {});
            },
          ),
      ],
    );
  }
}

// 2. Tarjeta verde con las cifras principales.
class _Resumen extends StatelessWidget {
  const _Resumen({this.animales, this.miembros});

  final int? animales, miembros;

  @override
  Widget build(BuildContext context) {
    Widget cifra(int? n, String texto) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            n?.toString() ?? '–',
            style: const TextStyle(
              fontFamily: fuenteTitulos,
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          Text(texto, style: const TextStyle(fontSize: 12, color: colorVerdeSuave)),
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: colorVerde, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Operaciones de la granja',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colorVerdeSuave),
          ),
          const SizedBox(height: 12),
          Row(children: [cifra(animales, 'Animales activos'), cifra(miembros, 'Miembros')]),
        ],
      ),
    );
  }
}

// 3. Barras con la cantidad de animales por etapa.
class _PorEtapa extends StatelessWidget {
  const _PorEtapa(this.ganado);

  final List<Animal> ganado;

  @override
  Widget build(BuildContext context) {
    if (ganado.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Tarjeta(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ganado por etapa', style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 12),
            for (final etapa in Etapa.values.reversed)
              Builder(
                builder: (context) {
                  final n = ganado.where((a) => a.etapa == etapa).length;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        SizedBox(width: 76, child: Text(etapa.etiqueta, style: Theme.of(context).textTheme.bodySmall)),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: n / ganado.length,
                              minHeight: 8,
                              color: colorVerde,
                              backgroundColor: colorVerdeSuave,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 32,
                          child: Text(
                            '$n',
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontWeight: FontWeight.w600, color: colorVerdeOscuro),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
