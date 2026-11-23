import 'package:flutter/material.dart';

import '../../logic/granjas.dart';
import '../../models/granja.dart';
import '../../widgets/panel_rol.dart';
import '../../widgets/pantalla.dart';
import '../../widgets/vetlink.dart';
import 'confirmar_granja_screen.dart';

class SolicitudesGranjaScreen extends StatefulWidget {
  const SolicitudesGranjaScreen({super.key});

  @override
  State<SolicitudesGranjaScreen> createState() => _SolicitudesGranjaScreenState();
}

class _SolicitudesGranjaScreenState extends State<SolicitudesGranjaScreen> {
  late Future<List<Granja>> _pendientes = Granjas.instance.porConfirmar();

  /// 1. Vuelve a pedir las granjas en revisión.
  void _recargar() {
    setState(() {
      _pendientes = Granjas.instance.porConfirmar();
    });
  }

  /// 2. Abre la solicitud; si se confirmó, avisa y actualiza la lista.
  Future<void> _revisar(Granja granja) async {
    final confirmada = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ConfirmarGranjaScreen(granja: granja)),
    );
    if (!mounted || confirmada == null) return;
    avisar(context, confirmada ? '${granja.nombre} quedó confirmada' : '${granja.nombre}: solicitud rechazada');
    _recargar();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    return Pantalla(
      titulo: 'Confirmar granjas',
      subtitulo: 'Revisá cada solicitud antes de confirmar la granja.',
      rol: 'Administrador técnico',
      granja: 'Todas las granjas',
      children: [
        FutureBuilder<List<Granja>>(
          future: _pendientes,
          builder: (context, estado) {
            if (estado.hasError) {
              return TextButton(
                style: TextButton.styleFrom(foregroundColor: colorRojo),
                onPressed: _recargar,
                child: const Text('No se pudieron cargar las granjas. Reintentar'),
              );
            }
            final granjas = estado.data;
            if (granjas == null) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${granjas.length} ${granjas.length == 1 ? 'granja' : 'granjas'} por confirmar',
                  style: tema.labelLarge?.copyWith(color: colorVerdeOscuro, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                if (granjas.isEmpty)
                  Text('No hay solicitudes pendientes.', style: tema.bodySmall?.copyWith(color: colorTextoSuave)),
                for (final granja in granjas)
                  OpcionPanel(
                    titulo: '${granja.nombre} · Pendiente',
                    detalle: 'Dueño: ${granja.dueno}\nRUNSA: ${granja.runsa}',
                    alPresionar: () => _revisar(granja),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
