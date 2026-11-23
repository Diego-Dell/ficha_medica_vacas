import 'package:flutter/material.dart';

import '../../logic/granjas.dart';
import '../../models/granja.dart';
import '../../widgets/panel_rol.dart';
import '../../widgets/vetlink.dart';
import '../../widgets/menu_granjas_administrador.dart';
import 'solicitudes_granja_screen.dart';

class AdministracionScreen extends StatefulWidget {
  const AdministracionScreen({super.key, this.alCerrarSesion, this.granja});
  final Granja? granja;

  final VoidCallback? alCerrarSesion;

  @override
  State<AdministracionScreen> createState() => _AdministracionScreenState();
}

class _AdministracionScreenState extends State<AdministracionScreen> {
  late Future<List<Granja>> _pendientes = Granjas.instance.porConfirmar();
  late Granja? _seleccionada = widget.granja;

  void _recargar() {
    setState(() { _pendientes = Granjas.instance.porConfirmar(); });
  }

  Future<void> _revisar() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const SolicitudesGranjaScreen()));
    if (mounted) _recargar();
  }

  @override
  Widget build(BuildContext context) => PanelRol(
    rol: 'Administrador',
    granja: _seleccionada?.nombre ?? 'Todas las granjas',
    mostrarGanado: false,
    menuLateral: MenuGranjasAdministrador(
      seleccionada: _seleccionada,
      alSeleccionar: (granja) => setState(() { _seleccionada = granja; }),
    ),
    alCerrarSesion: widget.alCerrarSesion,
    children: [
      // 1. Solicitudes por confirmar, directo en el inicio.
      FutureBuilder<List<Granja>>(
        future: _pendientes,
        builder: (context, estado) {
          if (estado.hasError) {
            return TextButton(
              onPressed: _recargar,
              child: const Text('No se pudieron cargar las granjas. Reintentar'),
            );
          }
          final pendientes = estado.data;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(color: colorVerde, borderRadius: BorderRadius.circular(24)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Gestión general del sistema',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colorVerdeSuave)),
                  const SizedBox(height: 8),
                  Text(pendientes == null ? '–' : '${pendientes.length}',
                      style: const TextStyle(fontFamily: fuenteTitulos, fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white)),
                  Text(
                    pendientes == null ? 'Consultando solicitudes...'
                        : '${pendientes.length == 1 ? 'granja' : 'granjas'} por confirmar',
                    style: const TextStyle(fontSize: 12, color: colorVerdeSuave),
                  ),
                ]),
              ),
              if (pendientes != null && pendientes.isEmpty)
                const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('No hay solicitudes pendientes.')),
              if (pendientes != null && pendientes.isNotEmpty) ...[
                const TituloGrupo('Por confirmar'),
                for (final g in pendientes)
                  OpcionPanel(titulo: g.nombre, detalle: g.dueno.isEmpty ? null : g.dueno, icono: 'granja', alPresionar: _revisar),
              ],
            ],
          );
        },
      ),
      const OpcionPanel(titulo: 'Cuentas y accesos', icono: 'miembros', alPresionar: null),
      if (_seleccionada != null) ...[
        TextButton.icon(onPressed: () => setState(() { _seleccionada = null; }),
          icon: const Icono('volver', color: colorVerde, tam: 18), label: const Text('Volver a gestión general')),
        TituloGrupo('Operaciones en ${_seleccionada!.nombre}'),
        const Accesos(children: [
          Acceso(titulo: 'Ganado e historial', icono: 'ganado', alPresionar: null),
          Acceso(titulo: 'Operaciones', icono: 'granja', alPresionar: null),
        ]),
      ],
    ],
  );
}
