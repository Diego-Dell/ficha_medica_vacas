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
    titulo: 'Administración',
    subtitulo: 'Gestión general del sistema.',
    rol: 'Administrador',
    granja: _seleccionada?.nombre ?? 'Todas las granjas',
    menuLateral: MenuGranjasAdministrador(
      seleccionada: _seleccionada,
      alSeleccionar: (granja) => setState(() { _seleccionada = granja; }),
    ),
    alCerrarSesion: widget.alCerrarSesion,
    children: [
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
          return Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(color: colorVerdeSuave, borderRadius: BorderRadius.circular(10)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                pendientes == null ? 'Consultando solicitudes...' : '${pendientes.length} ${pendientes.length == 1 ? 'granja' : 'granjas'} por confirmar',
                style: const TextStyle(color: colorVerdeOscuro, fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                pendientes == null ? 'Cargando datos.' : pendientes.isEmpty
                    ? 'No hay solicitudes pendientes.'
                    : 'Solicitudes recibidas: ${pendientes.map((g) => g.nombre).join(', ')}.',
                style: const TextStyle(color: colorTextoSuave, fontSize: 12),
              ),
            ]),
          );
        },
      ),
      const OpcionPanel(titulo: 'Cuentas y accesos', detalle: 'Corregir datos, recuperar o desactivar accesos.', alPresionar: null),
      OpcionPanel(titulo: 'Confirmar granjas', detalle: 'Revisar datos y documentación.', alPresionar: _revisar),
      if (_seleccionada != null) ...[
        TextButton.icon(onPressed: () => setState(() { _seleccionada = null; }),
          icon: const Icon(Icons.arrow_back, size: 18), label: const Text('Volver a gestión general')),
        Padding(padding: const EdgeInsets.only(bottom: 12),
          child: Text('Operaciones en ${_seleccionada!.nombre}',
            style: const TextStyle(color: colorTextoSuave, fontSize: 13, fontWeight: FontWeight.w600))),
        const OpcionPanel(titulo: 'Ganado e historial', detalle: 'Consulta de fichas y antecedentes.', alPresionar: null),
        const OpcionPanel(titulo: 'Operaciones de la granja', detalle: 'Gestión de fichas del ganado.', alPresionar: null),
      ],
    ],
  );
}
