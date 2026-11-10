import 'package:flutter/material.dart';

import '../../logic/granjas.dart';
import '../../models/granja.dart';
import '../../widgets/pantalla.dart';
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
    if (_confirmando) return;
    setState(() => _confirmando = true);
    final error = await Granjas.instance.confirmarSolicitudGranja(
      widget.granja.id,
    );
    if (!mounted) return;
    setState(() => _confirmando = false);
    if (error != null) {
      avisar(context, error);
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) => Pantalla(
    titulo: 'Confirmar granja',
    subtitulo: 'Revisa la solicitud antes de habilitar el acceso.',
    granja: widget.granja.nombre,
    rol: 'Administrador',
    children: [
      _SeccionDatos(
        titulo: 'Solicitud pendiente',
        children: [
          Text(
            widget.granja.nombre,
            style: const TextStyle(
              color: colorVerdeOscuro,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Text(
            'Pendiente de revisión',
            style: TextStyle(color: colorTextoSuave, fontSize: 12),
          ),
        ],
      ),
      const SizedBox(height: 10),
      _SeccionDatos(
        titulo: 'Datos recibidos',
        children: [
          _DatoSolicitud(etiqueta: 'Dueño', valor: widget.granja.dueno),
          if (widget.granja.correoDueno.isNotEmpty)
            _DatoSolicitud(
              etiqueta: 'Cuenta registrada',
              valor: widget.granja.correoDueno,
            ),
          _DatoSolicitud(
            etiqueta: 'Superficie',
            valor:
                '${_formatearSuperficie(widget.granja.superficie)} hectáreas',
          ),
          _DatoSolicitud(etiqueta: 'RUNSA', valor: widget.granja.runsa),
        ],
      ),
      const SizedBox(height: 10),
      _SeccionDatos(
        titulo: 'Documento del terreno',
        children: [
          Row(
            children: [
              const Icon(Icons.picture_as_pdf_outlined, color: colorVerde),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.granja.documento.isEmpty
                      ? 'No se indicó el nombre de un documento.'
                      : widget.granja.documento,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: colorVerdeOscuro,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Nombre del archivo registrado en la solicitud.',
            style: TextStyle(color: colorTextoSuave, fontSize: 11),
          ),
        ],
      ),
      const SizedBox(height: 16),
      BotonPrincipal(
        texto: _confirmando ? 'Confirmando...' : 'Confirmar registro',
        alPresionar: _confirmando ? null : _confirmar,
      ),
      BotonSecundario(
        texto: 'Volver a solicitudes',
        alPresionar: _confirmando ? null : () => Navigator.pop(context),
      ),
    ],
  );
}

String _formatearSuperficie(double valor) =>
    valor == valor.roundToDouble() ? valor.toStringAsFixed(0) : '$valor';

class _SeccionDatos extends StatelessWidget {
  const _SeccionDatos({required this.titulo, required this.children});

  final String titulo;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
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
          titulo,
          style: const TextStyle(
            color: colorVerdeOscuro,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    ),
  );
}

class _DatoSolicitud extends StatelessWidget {
  const _DatoSolicitud({required this.etiqueta, required this.valor});

  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: RichText(
      text: TextSpan(
        style: const TextStyle(color: colorTextoSuave, fontSize: 12),
        children: [
          TextSpan(
            text: '$etiqueta: ',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          TextSpan(text: valor),
        ],
      ),
    ),
  );
}
