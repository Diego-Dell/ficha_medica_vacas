import 'package:flutter/material.dart';

import '../logic/granjas.dart';
import '../models/granja.dart';
import 'vetlink.dart';

/// Cambia el contexto de trabajo sin cambiar el rol ni reemplazar el panel.
class MenuGranjasAdministrador extends StatefulWidget {
  const MenuGranjasAdministrador({super.key, required this.alSeleccionar, this.seleccionada});
  final ValueChanged<Granja?> alSeleccionar;
  final Granja? seleccionada;

  @override
  State<MenuGranjasAdministrador> createState() => _MenuGranjasAdministradorState();
}

class _MenuGranjasAdministradorState extends State<MenuGranjasAdministrador> {
  late Future<List<Granja>> _granjas = Granjas.instance.todas();

  @override
  void didUpdateWidget(covariant MenuGranjasAdministrador oldWidget) {
    super.didUpdateWidget(oldWidget);
    _granjas = Granjas.instance.todas();
  }

  void _elegir(Granja? granja) {
    Navigator.pop(context);
    widget.alSeleccionar(granja);
  }

  @override
  Widget build(BuildContext context) => Drawer(
    width: MediaQuery.sizeOf(context).width * .72,
    backgroundColor: const Color(0xFFF7F8F0),
    shape: const RoundedRectangleBorder(),
    child: SafeArea(child: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Align(alignment: Alignment.centerRight, child: TextButton(
          onPressed: () => Navigator.pop(context), child: const Text('Cerrar ×'))),
        const Text('Cambiar de granja', style: TextStyle(fontSize: 22,
          fontWeight: FontWeight.w600, color: colorVerdeOscuro)),
        const SizedBox(height: 12),
        ListTile(contentPadding: EdgeInsets.zero, title: const Text('Gestión general'),
          subtitle: const Text('Todas las granjas'), onTap: () => _elegir(null)),
        const Divider(),
        FutureBuilder<List<Granja>>(future: _granjas, builder: (context, estado) {
          if (estado.hasError) {
            return TextButton(onPressed: () => setState(() { _granjas = Granjas.instance.todas(); }),
              child: const Text('No se pudo cargar la lista de granjas. Reintentar'));
          }
          if (!estado.hasData) return const Center(child: CircularProgressIndicator());
          if (estado.data!.isEmpty) return const Text('No hay granjas registradas.');
          return Column(children: [for (final granja in estado.data!)
            Padding(padding: const EdgeInsets.only(bottom: 12), child: Material(
              color: Colors.white, borderRadius: BorderRadius.circular(10),
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                title: Text(granja.nombre, style: const TextStyle(color: colorVerde, fontWeight: FontWeight.w600)),
                subtitle: Text(granja.rechazada ? 'Solicitud rechazada' : !granja.confirmada ? 'En revisión'
                  : widget.seleccionada?.id == granja.id ? 'Granja seleccionada' : 'Confirmada'),
                trailing: Icon(widget.seleccionada?.id == granja.id ? Icons.check : Icons.chevron_right,
                  color: colorVerde, size: 18),
                onTap: () => _elegir(granja),
              ),
            )),
          ]);
        }),
      ],
    )),
  );
}
