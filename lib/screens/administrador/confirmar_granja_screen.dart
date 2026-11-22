import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../logic/documentos.dart';

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
  bool _abriendo = false;

  Future<void> _abrirDocumento() async {
    if (_abriendo) return;
    setState(() => _abriendo = true);
    try {
      final enlace = await Granjas.instance.enlaceDocumento(widget.granja);
      if (!await launchUrl(Uri.parse(enlace), mode: LaunchMode.externalApplication)) {
        throw Exception('No se pudo abrir');
      }
    } on Exception {
      if (mounted) avisar(context, 'No se pudo abrir el documento. Revisá tu conexión e intentá nuevamente');
    } finally {
      if (mounted) setState(() => _abriendo = false);
    }
  }

  Future<void> _rechazar() async {
    if (_confirmando) return;
    var motivo = '';
    final form = GlobalKey<FormState>();
    final texto = await showDialog<String>(
      context: context,
      builder: (dialogo) => AlertDialog(
        title: const Text('Rechazar solicitud'),
        content: Form(
          key: form,
          child: TextFormField(
            onChanged: (valor) => motivo = valor,
            maxLength: 500,
            maxLines: 3,
            decoration: decoracionCampo(pista: 'Motivo que verá el dueño'),
            validator: requerido,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogo),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(dialogo, motivo.trim());
              }
            },
            child: const Text('Rechazar'),
          ),
        ],
      ),
    );
    if (texto == null || !mounted) return;
    setState(() => _confirmando = true);
    final error = await Granjas.instance.rechazar(widget.granja, texto);
    if (!mounted) return;
    setState(() => _confirmando = false);
    if (error != null) {
      avisar(context, error);
    } else {
      Navigator.pop(context, false);
    }
  }

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
          dato(Documentos.subido(granja.documento)
              ? Documentos.nombre(granja.documento)
              : 'El dueño todavía no subió el archivo'),
          if (Documentos.subido(granja.documento))
            BotonSecundario(texto: _abriendo ? 'Abriendo...' : 'Abrir documento',
              alPresionar: _abriendo ? null : _abrirDocumento),
        ]),
        BotonPrincipal(
          texto: _confirmando ? 'Confirmando...' : 'Confirmar registro',
          alPresionar: _confirmando || !Documentos.subido(granja.documento) ? null : _confirmar,
        ),
        BotonSecundario(texto: 'Rechazar solicitud', alPresionar: _confirmando ? null : _rechazar),
        BotonSecundario(texto: 'Volver', alPresionar: volver),
      ],
    );
  }
}
