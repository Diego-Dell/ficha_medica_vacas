import 'package:flutter/material.dart';

import '../../logic/granjas.dart';
import '../../models/granja.dart';
import '../../widgets/panel_rol.dart';
import '../../widgets/vetlink.dart';
import 'confirmar_granja_screen.dart';

class AdministracionScreen extends StatefulWidget {
  const AdministracionScreen({super.key, this.alCerrarSesion});

  final VoidCallback? alCerrarSesion;

  @override
  State<AdministracionScreen> createState() => _AdministracionScreenState();
}

class _AdministracionScreenState extends State<AdministracionScreen> {
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
    if (!mounted || confirmada != true) return;
    avisar(context, '${granja.nombre} quedó confirmada');
    _recargar();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    return PanelRol(
      titulo: 'Administración',
      subtitulo: 'Revisá cada solicitud antes de confirmar la granja.',
      rol: 'Administrador técnico',
      granja: 'Todas las granjas',
      alCerrarSesion: widget.alCerrarSesion,
      cambiarGranja: false,
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
