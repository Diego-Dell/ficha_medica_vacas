import 'package:flutter/material.dart';

import '../logic/sesion.dart';
import 'menu_granjas.dart';
import '../screens/dueno_granja/registrar_otra_granja_screen.dart';
import 'pantalla.dart';
import 'vetlink.dart';

/// 1. Muestra una opción del panel que abre otra pantalla.
class OpcionPanel extends StatelessWidget {
  const OpcionPanel({
    super.key,
    required this.titulo,
    required this.detalle,
    required this.alPresionar,
  });

  final String titulo, detalle;
  final VoidCallback? alPresionar;

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
        onTap: alPresionar,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$titulo  ›',
                style: const TextStyle(
                  color: colorVerde,
                  fontSize: 16,
                  height: 23 / 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                detalle,
                style: const TextStyle(
                  color: colorTextoSuave,
                  fontSize: 13,
                  height: 19 / 13,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// 2. Cierra la sesión y vuelve al login.
Future<void> cerrarSesion(BuildContext context) async {
  await Sesion.instance.cerrar();
  if (context.mounted) Navigator.popUntil(context, (ruta) => ruta.isFirst);
}

/// 3. Arma el inicio de cada rol con la barra para cerrar sesión y cambiar de granja.
class PanelRol extends StatelessWidget {
  const PanelRol({
    super.key,
    required this.rol,
    required this.granja,
    required this.children,
    this.titulo = 'Mi granja',
    this.subtitulo,
    this.alCerrarSesion,
    this.cambiarGranja = true,
    this.alRegistrarGranja,
    this.mostrarReportes = true,
    this.menuLateral,
  });

  final String rol, granja, titulo;
  final String? subtitulo;
  final List<Widget> children;
  final VoidCallback? alCerrarSesion;
  final VoidCallback? alRegistrarGranja;
  final bool mostrarReportes;
  final Widget? menuLateral;

  /// Controla si se muestra el menú de granjas.
  final bool cambiarGranja;

  @override
  Widget build(BuildContext context) => Pantalla(
    titulo: titulo,
    subtitulo: subtitulo ?? '$granja · $rol',
    granja: granja,
    rol: rol,
    volver: false,
    menuLateral: menuLateral ?? (cambiarGranja ? MenuGranjas(
      alRegistrar: alRegistrarGranja ?? () => Navigator.push(context,
        MaterialPageRoute(builder: (_) => const RegistrarOtraGranjaScreen())),
    ) : null),
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
                child: TextButton(
                  onPressed: alCerrarSesion ?? () => cerrarSesion(context),
                  child: const Text(
                    'Cerrar sesión',
                    style: TextStyle(fontSize: 12, color: colorVerde),
                  ),
                ),
              ),
              const Expanded(child: TextButton(onPressed: null, child: Text('Avisos', style: TextStyle(fontSize: 12)))),
              if (mostrarReportes)
                const Expanded(child: TextButton(onPressed: null, child: Text('Reportes', style: TextStyle(fontSize: 12)))),
              if (cambiarGranja)
                Builder(builder: (context) => IconButton(
                  tooltip: 'Opciones',
                  icon: const Icon(Icons.menu, color: colorVerde),
                  onPressed: () => Scaffold.of(context).openEndDrawer(),
                ))
              else
                const IconButton(onPressed: null, tooltip: 'Opciones', icon: Icon(Icons.menu)),
            ],
          ),
        ),
      ),
    ),
    children: [const SizedBox(height: 4), ...children],
  );
}
