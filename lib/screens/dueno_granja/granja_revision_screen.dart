import 'package:flutter/material.dart';

import '../../models/granja.dart';
import '../../widgets/vetlink.dart';
import '../../logic/sesion.dart';

class GranjaRevisionScreen extends StatefulWidget {
  const GranjaRevisionScreen({super.key, required this.granja, this.correoConfirmacion, this.correoEnviado = true});

  final Granja granja;
  final String? correoConfirmacion;
  final bool correoEnviado;

  @override
  State<GranjaRevisionScreen> createState() => _GranjaRevisionScreenState();
}

class _GranjaRevisionScreenState extends State<GranjaRevisionScreen> {
  Granja get granja => widget.granja;
  bool _reenviando = false;
  bool _correoReintentado = false;

  Future<void> _reenviar() async {
    if (_reenviando) return;
    setState(() => _reenviando = true);
    final error = await Sesion.instance.reenviarConfirmacion(widget.correoConfirmacion!);
    if (!mounted) return;
    setState(() { _reenviando = false; _correoReintentado = error == null; });
    avisar(context, error ?? 'Se solicitó el correo de confirmación. Revisá tu correo y spam');
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    return PantallaVetLink(
      titulo: granja.rechazada ? 'Solicitud rechazada' : 'Granja en revisión',
      subtitulo: 'Recibimos el registro de ${granja.nombre}.',
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: colorAmbarFondo, borderRadius: BorderRadius.circular(10)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                granja.rechazada ? 'Motivo del rechazo' : 'Pendiente de confirmación',
                style: tema.labelLarge?.copyWith(color: colorAmbarTexto, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                granja.motivoRechazo ?? 'El administrador revisará los datos y la documentación antes de habilitar el acceso.',
                style: tema.bodySmall?.copyWith(color: colorAmbarTexto),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: colorBorde),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                granja.nombre,
                style: tema.titleSmall?.copyWith(color: colorVerdeOscuro, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              for (final dato in ['Dueño: ${granja.dueno}', 'RUNSA: ${granja.runsa}'])
                Text(dato, style: tema.bodySmall?.copyWith(color: colorTextoSuave)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text('Documentación recibida', style: tema.bodySmall?.copyWith(color: colorTextoSuave)),
        if (!widget.correoEnviado && widget.correoConfirmacion != null) ...[
          const SizedBox(height: 12),
          Text(_correoReintentado ? 'Revisá tu correo y spam para confirmar la cuenta.'
            : 'La solicitud y el PDF están guardados, pero no se pudo enviar el correo de confirmación. Reintentá el envío para poder iniciar sesión.',
            style: tema.bodySmall?.copyWith(color: colorAmbarTexto)),
          BotonSecundario(texto: _reenviando ? 'Reenviando...' : 'Reenviar correo de confirmación',
            alPresionar: _reenviando ? null : _reenviar),
        ],
        const SizedBox(height: 12),
        Text(
          granja.rechazada
              ? 'La solicitud se conserva. Consultá al administrador antes de volver a registrarla.'
              : 'Una vez confirmada, podrás entrar a tu granja e invitar al equipo.',
          style: tema.bodySmall?.copyWith(color: colorTextoSuave),
        ),
        const SizedBox(height: 12),
        BotonSecundario(
          texto: 'Volver al login',
          alPresionar: () => Navigator.popUntil(context, (ruta) => ruta.isFirst),
        ),
      ],
    );
  }
}
