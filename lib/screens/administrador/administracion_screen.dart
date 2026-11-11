import 'package:flutter/material.dart';

import '../../logic/granjas.dart';
import '../../models/granja.dart';
import '../../widgets/panel_rol.dart';
import '../../widgets/vetlink.dart';

class AdministracionScreen extends StatefulWidget {
  const AdministracionScreen({super.key, this.alCerrarSesion});

  final VoidCallback? alCerrarSesion;

  @override
  State<AdministracionScreen> createState() => _AdministracionScreenState();
}

class _AdministracionScreenState extends State<AdministracionScreen> {
  late Future<List<Granja>> _pendientes = Granjas.instance.porConfirmar();
  String? _confirmando;

  /// 1. Vuelve a pedir las granjas en revisión.
  void _recargar() {
    setState(() {
      _pendientes = Granjas.instance.porConfirmar();
    });
  }

  /// 2. Confirma la granja elegida para que su dueño pueda entrar e invitar al equipo.
  Future<void> _confirmar(Granja granja) async {
    // 2.1. Evita confirmar dos granjas a la vez.
    if (_confirmando != null) return;
    setState(() => _confirmando = granja.id);

    // 2.2. Pide a Supabase confirmar la granja.
    final error = await Granjas.instance.confirmar(granja);
    if (!mounted) return;
    setState(() => _confirmando = null);

    // 2.3. Muestra el error o avisa el resultado y actualiza la lista.
    if (error != null) {
      avisar(context, error);
      return;
    }
    avisar(context, '${granja.nombre} quedó confirmada');
    _recargar();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    return PanelRol(
      titulo: 'Administración',
      subtitulo: 'Revisá los datos y la documentación antes de confirmar cada granja.',
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
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: colorBorde),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          granja.nombre,
                          style: tema.titleSmall?.copyWith(color: colorVerdeOscuro, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        for (final dato in [
                          'RUNSA: ${granja.runsa}',
                          'Superficie: ${granja.superficie.toStringAsFixed(granja.superficie % 1 == 0 ? 0 : 2)} ha',
                          'Documentación: ${granja.documento.isEmpty ? 'Sin archivo' : granja.documento}',
                        ])
                          Text(dato, style: tema.bodySmall?.copyWith(color: colorTextoSuave)),
                        const SizedBox(height: 10),
                        BotonPrincipal(
                          texto: _confirmando == granja.id ? 'Confirmando...' : 'Confirmar granja',
                          alPresionar: _confirmando == null ? () => _confirmar(granja) : null,
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
