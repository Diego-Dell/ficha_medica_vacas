import 'package:flutter/material.dart';

import '../../logic/granjas.dart';
import '../../models/granja.dart';
import '../../widgets/vetlink.dart';

class ConfirmarGranjaScreen extends StatefulWidget {
  const ConfirmarGranjaScreen({super.key, required this.granja});

  final Granja granja;

  @override
  State<ConfirmarGranjaScreen> createState() => _ConfirmarGranjaScreenState();
}

class _ConfirmarGranjaScreenState extends State<ConfirmarGranjaScreen> {
  bool _confirmando = false;

  Future<void> _confirmar() async {
    // 1. Evita confirmar dos veces la misma granja.
    if (_confirmando) return;
    setState(() => _confirmando = true);

    // 2. Pide a Supabase confirmar la granja.
    final error = await Granjas.instance.confirmar(widget.granja);
    if (!mounted) return;
    setState(() => _confirmando = false);

    // 3. Muestra el error o vuelve a Administración avisando que quedó confirmada.
    if (error != null) {
      avisar(context, error);
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    final granja = widget.granja;
    final superficie = granja.superficie.toStringAsFixed(granja.superficie % 1 == 0 ? 0 : 2);
    void volver() => Navigator.pop(context);

    Widget tarjeta(List<Widget> contenido) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: colorBorde),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: contenido),
        );
    Widget titulo(String texto) =>
        Text(texto, style: tema.titleSmall?.copyWith(color: colorVerdeOscuro, fontWeight: FontWeight.w700));
    Widget dato(String texto) => Text(texto, style: tema.bodySmall?.copyWith(color: colorTextoSuave));

    return PantallaVetLink(
      encabezado: EncabezadoVetLink(rol: 'Administrador técnico', alVolver: volver),
      titulo: 'Confirmar granja',
      subtitulo: 'Revisá la solicitud antes de habilitar el acceso.',
      children: [
        tarjeta([titulo('${granja.nombre} · Pendiente')]),
        tarjeta([
          titulo('Datos recibidos'),
          const SizedBox(height: 4),
          dato('Dueño: ${granja.dueno}'),
          dato('Superficie: $superficie ha'),
          dato('RUNSA: ${granja.runsa}'),
        ]),
        tarjeta([
          titulo('Documentación del terreno'),
          const SizedBox(height: 4),
          dato(granja.documento.isEmpty ? 'Sin archivo adjunto' : '${granja.documento} · Archivo adjunto a la solicitud'),
        ]),
        BotonPrincipal(
          texto: _confirmando ? 'Confirmando...' : 'Confirmar registro',
          alPresionar: _confirmando ? null : _confirmar,
        ),
        BotonSecundario(texto: 'Volver', alPresionar: volver),
      ],
    );
  }
}
