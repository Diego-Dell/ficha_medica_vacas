import 'package:flutter/material.dart';

import '../../logic/granjas.dart';
import '../../widgets/pantalla.dart';
import '../../widgets/vetlink.dart';
import '../inicio_por_rol.dart';

class SeleccionarGranjaScreen extends StatefulWidget {
  const SeleccionarGranjaScreen({super.key, this.vinculos});

  /// Granjas ya cargadas al iniciar sesión; sin ellas, la pantalla las pide a Supabase.
  final List<Vinculo>? vinculos;

  @override
  State<SeleccionarGranjaScreen> createState() => _SeleccionarGranjaScreenState();
}

class _SeleccionarGranjaScreenState extends State<SeleccionarGranjaScreen> {
  late Future<List<Vinculo>> _vinculos = _cargar();

  /// 1. Usa las granjas recibidas o las pide a Supabase.
  Future<List<Vinculo>> _cargar() async => widget.vinculos ?? await Granjas.instance.misVinculos();

  /// 2. Vuelve a pedir las granjas.
  void _recargar() {
    setState(() {
      _vinculos = Granjas.instance.misVinculos();
    });
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    return Pantalla(
      titulo: 'Mis granjas',
      subtitulo: 'Elegí la granja con la que vas a trabajar. Tu rol se recupera en cada una.',
      children: [
        FutureBuilder<List<Vinculo>>(
          future: _vinculos,
          builder: (context, estado) {
            if (estado.hasError) {
              return TextButton(
                style: TextButton.styleFrom(foregroundColor: colorRojo),
                onPressed: _recargar,
                child: const Text('No se pudieron cargar tus granjas. Reintentar'),
              );
            }
            final vinculos = estado.data;
            if (vinculos == null) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (vinculos.isEmpty) {
              return Text('Tu cuenta todavía no tiene una granja.', style: tema.bodyMedium?.copyWith(color: colorTextoSuave));
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [for (final vinculo in vinculos) _OpcionGranja(vinculo: vinculo)],
            );
          },
        ),
      ],
    );
  }
}

class _OpcionGranja extends StatelessWidget {
  const _OpcionGranja({required this.vinculo});

  final Vinculo vinculo;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    final granja = vinculo.granja;
    final actual = Granjas.instance.esActual(granja);

    // 1. Cada granja muestra el rol de la persona y si ya está confirmada.
    final estado = granja.confirmada ? (actual ? 'Granja actual' : 'Confirmada') : 'En revisión';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: actual ? colorVerdeSuave : Colors.white,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: colorBorde),
          borderRadius: BorderRadius.circular(10),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          // 2. Entrar a la granja recupera el rol guardado en ella.
          onTap: () => InicioPorRol.entrar(context, vinculo),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        granja.nombre,
                        style: tema.titleSmall?.copyWith(color: colorVerdeOscuro, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${vinculo.rol.etiqueta} · $estado',
                        style: tema.bodySmall?.copyWith(color: granja.confirmada ? colorTextoSuave : colorAmbarTexto),
                      ),
                    ],
                  ),
                ),
                Icon(actual ? Icons.check : Icons.chevron_right, color: colorVerde),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
