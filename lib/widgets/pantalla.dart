import 'package:flutter/material.dart';

import 'vetlink.dart';

// 1. Pantalla con encabezado fijo; usa el mismo marco que PantallaVetLink.
class Pantalla extends StatelessWidget {
  const Pantalla({
    super.key,
    required this.titulo,
    required this.children,
    this.subtitulo,
    this.volver = true,
    this.barraInferior,
    this.menuLateral,
    this.granja,
    this.rol,
  });

  final String titulo;
  final String? subtitulo;
  final List<Widget> children;
  final bool volver;
  final Widget? barraInferior;
  final Widget? menuLateral;
  final String? granja;
  final String? rol;

  @override
  Widget build(BuildContext context) => MarcoPantalla(
        titulo: titulo,
        detalle: granja ?? rol ?? 'VetLink',
        subtitulo: subtitulo,
        alVolver: volver ? () => Navigator.maybePop(context) : null,
        barraInferior: barraInferior,
        menuLateral: menuLateral,
        children: children,
      );
}
