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
    final estado = granja.confirmada ? (actual ? 'Granja actual' : 'Confirmada') : granja.rechazada ? 'Solicitud rechazada' : 'En revisión';
    // 2. Tarjeta con ícono; entrar a la granja recupera el rol guardado en ella.
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Tarjeta(
        alPresionar: () => InicioPorRol.entrar(context, vinculo),
        child: Row(
          children: [
            BurbujaIcono('granja', fondo: actual ? colorVerde : colorVerdeSuave, color: actual ? Colors.white : colorVerde),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(granja.nombre, style: tema.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    '${vinculo.rol.etiqueta} · $estado',
                    style: tema.bodySmall?.copyWith(color: granja.confirmada ? colorTextoSuave : colorAmbarTexto),
                  ),
                ],
              ),
            ),
            Icono(actual ? 'check' : 'flecha', color: actual ? colorVerde : colorTextoSuave, tam: 20),
          ],
        ),
      ),
    );
  }
}
