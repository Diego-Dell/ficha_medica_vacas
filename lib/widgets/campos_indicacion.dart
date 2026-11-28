import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../logic/dosis.dart';

import 'vetlink.dart';

class FechaIndicacion extends StatelessWidget {
  const FechaIndicacion({
    super.key,
    required this.etiqueta,
    required this.fecha,
    required this.alCambiar,
    this.minima,
    this.maxima,
  });
  final String etiqueta;
  final DateTime fecha;
  final ValueChanged<DateTime> alCambiar;
  final DateTime? minima, maxima;

  @override
  Widget build(BuildContext context) => CampoEtiquetado(
    etiqueta: etiqueta,
    child: OutlinedButton.icon(
      icon: const Icono('calendario', tam: 20),
      label: Text(fechaCorta(fecha)),
      onPressed: () async {
        final desde = minima ?? DateTime(2000);
        final hasta = maxima ?? DateTime(DateTime.now().year + 5, 12, 31);
        final inicial = fecha.isBefore(desde)
            ? desde
            : fecha.isAfter(hasta)
            ? hasta
            : fecha;
        final elegida = await showDatePicker(
          context: context,
          initialDate: inicial,
          firstDate: desde,
          lastDate: hasta,
        );
        if (elegida != null) alCambiar(elegida);
      },
    ),
  );
}

class TextoIndicacion extends StatelessWidget {
  const TextoIndicacion({
    super.key,
    required this.etiqueta,
    required this.controlador,
    this.pista,
    this.maximo = 100,
    this.obligatorio = true,
    this.lineas = 1,
    this.validar,
    this.numerico = false,
  });
  final String etiqueta;
  final TextEditingController controlador;
  final String? pista;
  final int maximo, lineas;
  final bool obligatorio, numerico;
  final String? Function(String?)? validar;

  @override
  Widget build(BuildContext context) => CampoEtiquetado(
    etiqueta: etiqueta,
    child: TextFormField(
      controller: controlador,
      minLines: lineas,
      maxLines: lineas == 1 ? 1 : 5,
      maxLength: maximo,
      keyboardType: numerico
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      decoration: decoracionCampo(pista: pista).copyWith(counterText: ''),
      validator: validar ?? (obligatorio ? requerido : null),
    ),
  );
}

// 1. Unidad de la dosis elegida de una lista fija (F1).
class SelectorUnidad extends StatelessWidget {
  const SelectorUnidad({super.key, required this.controlador, this.etiqueta = 'Unidad *'});
  final TextEditingController controlador;
  final String etiqueta;

  @override
  Widget build(BuildContext context) => CampoEtiquetado(
    etiqueta: etiqueta,
    child: DropdownButtonFormField<String>(
      initialValue: unidadValida(controlador.text),
      isExpanded: true,
      decoration: decoracionCampo(pista: 'Elegir'),
      items: [for (final u in unidadesDosis) DropdownMenuItem(value: u, child: Text(u))],
      onChanged: (u) => controlador.text = u ?? '',
      validator: (u) => u == null ? 'Elegí la unidad' : null,
    ),
  );
}

// 2. Número entero en un rango, con sufijo (horas o días).
class EnteroIndicacion extends StatelessWidget {
  const EnteroIndicacion({
    super.key,
    required this.etiqueta,
    required this.controlador,
    required this.sufijo,
    required this.maximo,
  });
  final String etiqueta, sufijo;
  final TextEditingController controlador;
  final int maximo;

  @override
  Widget build(BuildContext context) => CampoEtiquetado(
    etiqueta: etiqueta,
    child: TextFormField(
      controller: controlador,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: decoracionCampo(pista: '0').copyWith(suffixText: sufijo),
      validator: (v) {
        final n = int.tryParse(v ?? '');
        return n == null || n < 1 || n > maximo ? 'Entre 1 y $maximo' : null;
      },
    ),
  );
}
