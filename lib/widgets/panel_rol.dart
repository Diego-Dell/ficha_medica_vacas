import 'package:flutter/material.dart';

import '../logic/reportes.dart';
import '../logic/sesion.dart';
import '../screens/dueno_granja/registrar_otra_granja_screen.dart';
import '../screens/ganado/ganado_screen.dart';
import '../screens/ganado/avisos_screen.dart';
import '../screens/perfil_screen.dart';
import '../screens/reportes_screen.dart';
import 'menu_granjas.dart';
import 'vetlink.dart';

/// 1. Fila tocable con ícono, título y detalle opcional.
class OpcionPanel extends StatelessWidget {
  const OpcionPanel({super.key, required this.titulo, this.detalle, required this.alPresionar, this.icono = 'ficha'});

  final String titulo;
  final String? detalle;
  final String icono;
  final VoidCallback? alPresionar;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Opacity(
      opacity: alPresionar == null ? .45 : 1,
      child: Tarjeta(
        alPresionar: alPresionar,
        child: Row(
          children: [
            BurbujaIcono(icono),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo, style: Theme.of(context).textTheme.titleMedium),
                  if (detalle != null) Text(detalle!, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            const Icono('flecha', color: colorTextoSuave, tam: 20),
          ],
        ),
      ),
    ),
  );
}

/// 2. Acceso de inicio: ícono y nombre corto, dos por fila.
class Acceso extends StatelessWidget {
  const Acceso({super.key, required this.titulo, required this.icono, required this.alPresionar});

  final String titulo, icono;
  final VoidCallback? alPresionar;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: alPresionar == null ? .45 : 1,
    child: Tarjeta(
      alPresionar: alPresionar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BurbujaIcono(icono),
          const SizedBox(height: 12),
          Text(
            titulo,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colorVerdeOscuro),
          ),
        ],
      ),
    ),
  );
}

/// 3. Grilla de accesos de dos columnas.
class Accesos extends StatelessWidget {
  const Accesos({super.key, required this.children});

  final List<Acceso> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, medida) {
      final ancho = (medida.maxWidth - 16) / 2;
      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [for (final a in children) SizedBox(width: ancho, child: a)],
      );
    },
  );
}

/// 4. Título de un grupo dentro del inicio.
class TituloGrupo extends StatelessWidget {
  const TituloGrupo(this.texto, {super.key});

  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 12),
    child: Text(texto, style: Theme.of(context).textTheme.titleMedium),
  );
}

/// 5. Cierra la sesión y vuelve al login.
Future<void> cerrarSesion(BuildContext context) async {
  await Sesion.instance.cerrar();
  if (context.mounted) Navigator.popUntil(context, (ruta) => ruta.isFirst);
}

/// Inicio de cada rol con acceso compartido a Ganado y Avisos.
class PanelRol extends StatefulWidget {
  const PanelRol({
    super.key,
    required this.rol,
    required this.granja,
    required this.children,
    this.alCerrarSesion,
    this.cambiarGranja = true,
    this.alRegistrarGranja,
    this.mostrarGanado = true,
    this.menuLateral,
  });

  final String rol, granja;
  final List<Widget> children;
  final VoidCallback? alCerrarSesion;
  final VoidCallback? alRegistrarGranja;
  final bool mostrarGanado;
  final Widget? menuLateral;

  /// Controla si el encabezado permite cambiar de granja.
  final bool cambiarGranja;

  @override
  State<PanelRol> createState() => _PanelRolState();
}

class _PanelRolState extends State<PanelRol> {
  int _pestana = 0;

  // 1. Pestañas disponibles según el rol (Reportes solo para dueño y veterinario).
  bool get _mostrarReportes =>
      widget.mostrarGanado &&
      widget.rol != 'Trabajador' &&
      Reportes.instance.puedeGenerar;

  List<(String, String)> get _pestanas => [
    ('Inicio', 'inicio'),
    if (widget.mostrarGanado) ('Ganado', 'ganado'),
    if (widget.mostrarGanado) ('Avisos', 'avisos'),
    if (_mostrarReportes) ('Reportes', 'reportes'),
    ('Perfil', 'perfil'),
  ];

  // 2. Cambio de granja: menú del administrador o la hoja de mis granjas.
  void _cambiarGranja(BuildContext context) {
    if (widget.menuLateral != null) {
      Scaffold.of(context).openEndDrawer();
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: colorSuperficie,
      isScrollControlled: true,
      builder: (_) => MenuGranjas(
        alRegistrar:
            widget.alRegistrarGranja ??
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegistrarOtraGranjaScreen())),
      ),
    );
  }

  Widget _inicio(BuildContext context) {
    final nombre = Sesion.instance.nombre.split(RegExp(r'[\s@]')).first;
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Builder(
                  builder: (context) => Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset('assets/images/logo.png', width: 40, height: 40),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Tooltip(
                          message: 'Cambiar de granja',
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: widget.cambiarGranja ? () => _cambiarGranja(context) : null,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  nombre.isEmpty ? 'Hola' : 'Hola, $nombre',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        '${widget.granja} · ${widget.rol}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                    ),
                                    if (widget.cambiarGranja) const Icono('flecha', color: colorTextoSuave, tam: 16),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ...widget.children,
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pestanas = _pestanas;
    final actual = pestanas[_pestana.clamp(0, pestanas.length - 1)].$1;
    return Scaffold(
      backgroundColor: colorFondo,
      endDrawer: widget.menuLateral,
      body: switch (actual) {
        'Ganado' => const GanadoScreen(enPestana: true),
        'Avisos' => const AvisosScreen(enPestana: true),
        'Reportes' => ReportesScreen(
          enPestana: true,
          alVolver: () => setState(() => _pestana = 0),
        ),
        'Perfil' => PerfilScreen(
          rol: widget.rol,
          granja: widget.granja,
          alCerrarSesion: widget.alCerrarSesion ?? () => cerrarSesion(context),
        ),
        _ => Builder(builder: _inicio),
      },
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: colorBorde, width: 0.5)),
        ),
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            labelTextStyle: WidgetStateProperty.resolveWith(
              (estados) => TextStyle(
                fontFamily: fuenteTexto,
                fontSize: 11.5,
                fontWeight: estados.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w500,
                color: estados.contains(WidgetState.selected) ? colorVerdeOscuro : colorTextoSuave,
              ),
            ),
          ),
          child: NavigationBar(
            backgroundColor: colorSuperficie,
            indicatorColor: colorVerdeSuave,
            surfaceTintColor: Colors.transparent,
            height: 72,
            selectedIndex: _pestana.clamp(0, pestanas.length - 1),
            onDestinationSelected: (i) => setState(() => _pestana = i),
            destinations: [
              for (final (titulo, icono) in pestanas)
                NavigationDestination(
                  icon: Icono(icono, color: colorTextoSuave, tam: 22),
                  selectedIcon: Icono(icono, color: colorVerde, tam: 22),
                  label: titulo,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
