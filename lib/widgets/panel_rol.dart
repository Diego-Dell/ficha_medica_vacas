import 'package:flutter/material.dart';

import 'pantalla.dart';
import 'vetlink.dart';

/// Opciones visuales de los paneles; cada destino puede conectarse después.
class OpcionPanel extends StatelessWidget {
  const OpcionPanel({
    super.key,
    required this.titulo,
    required this.detalle,
    this.alPresionar,
    this.compacta = false,
  });

  final String titulo, detalle;
  final VoidCallback? alPresionar;
  final bool compacta;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: colorBorde),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: alPresionar ?? () => mostrarPendiente(context, titulo),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$titulo  ›',
                style: TextStyle(
                  color: colorVerde,
                  fontSize: compacta ? 14 : 16,
                  height: compacta ? 21 / 14 : 23 / 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                detalle,
                style: TextStyle(
                  color: colorTextoSuave,
                  fontSize: compacta ? 12 : 13,
                  height: compacta ? 17 / 12 : 19 / 13,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Avisa honestamente cuando el destino todavía no forma parte de la app.
void mostrarPendiente(BuildContext context, String titulo) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    title: Text(titulo),
    content: const Text('Esta sección todavía no está disponible.'),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Entendido'),
      ),
    ],
  ),
);

class PanelRol extends StatelessWidget {
  const PanelRol({
    super.key,
    required this.rol,
    required this.granja,
    required this.children,
    this.titulo = 'Mi granja',
    this.subtitulo,
    this.alCerrarSesion,
  });

  final String rol, granja, titulo;
  final String? subtitulo;
  final List<Widget> children;
  final VoidCallback? alCerrarSesion;

  @override
  Widget build(BuildContext context) => Pantalla(
    titulo: titulo,
    subtitulo: subtitulo ?? '$granja · $rol',
    granja: granja,
    rol: rol,
    barraInferior: Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: colorBorde)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              Expanded(
                flex: 112,
                child: TextButton(
                  onPressed:
                      alCerrarSesion ??
                      () => Navigator.popUntil(context, (ruta) => ruta.isFirst),
                  child: const Text(
                    'Cerrar sesión',
                    style: TextStyle(fontSize: 12, color: colorVerde),
                  ),
                ),
              ),
              for (final texto in ['Avisos', 'Reportes'])
                Expanded(
                  flex: 89,
                  child: TextButton(
                    onPressed: () => mostrarPendiente(context, texto),
                    child: Text(
                      texto,
                      style: const TextStyle(fontSize: 12, color: colorVerde),
                    ),
                  ),
                ),
              Expanded(
                flex: 76,
                child: IconButton(
                  tooltip: 'Menú de granjas',
                  icon: const Icon(Icons.menu, color: colorVerde),
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    builder: (context) => SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Mis granjas',
                              style: TextStyle(
                                fontSize: 25,
                                color: colorVerdeOscuro,
                              ),
                            ),
                            ListTile(
                              title: Text(granja),
                              subtitle: const Text('Granja actual'),
                              trailing: const Icon(Icons.check),
                              onTap: () => Navigator.pop(context),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cerrar'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    children: [const SizedBox(height: 4), ...children],
  );
}
