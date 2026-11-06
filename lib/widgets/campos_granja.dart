import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'vetlink.dart';

/// 1. Abre el selector de archivos y devuelve el nombre del documento elegido.
Future<String?> elegirDocumento() async {
  final archivos = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
  );
  return archivos.isEmpty ? null : archivos.first.name;
}

/// 2. Valida que la superficie sea un número mayor a 0.
String? superficieValida(String? valor) {
  final numero = double.tryParse((valor ?? '').trim().replaceAll(',', '.'));
  if (numero == null) return 'Ingresa un número';
  return numero > 0 ? null : 'Debe ser mayor a 0';
}

/// 3. Convierte la superficie a número y acepta coma decimal.
double leerSuperficie(String valor) => double.parse(valor.trim().replaceAll(',', '.'));

/// 4. Muestra los campos para registrar una granja: nombre, superficie, RUNSA y documentación.
class CamposGranja extends StatelessWidget {
  const CamposGranja({
    super.key,
    required this.nombre,
    required this.superficie,
    required this.runsa,
    required this.alElegirDocumento,
    required this.elegir,
    this.compacto = false,
    this.etiquetaNombre = 'Nombre *',
    this.etiquetaDocumento = 'Documentación del terreno *',
  });

  final bool compacto;
  final TextEditingController nombre;
  final TextEditingController superficie;
  final TextEditingController runsa;
  final ValueChanged<String> alElegirDocumento;
  final Future<String?> Function() elegir;
  final String etiquetaNombre;
  final String etiquetaDocumento;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CampoEtiquetado(
          etiqueta: etiquetaNombre,
          child: TextFormField(
            controller: nombre,
            decoration: decoracionCampo(pista: compacto ? null : 'Los Pinos'),
            textCapitalization: TextCapitalization.words,
            validator: requerido,
          ),
        ),
        CampoEtiquetado(
          etiqueta: 'Superficie (hectáreas) *',
          child: TextFormField(
            controller: superficie,
            decoration: decoracionCampo(pista: compacto ? null : '18'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: superficieValida,
          ),
        ),
        CampoEtiquetado(
          etiqueta: 'RUNSA *',
          child: TextFormField(
            controller: runsa,
            decoration: decoracionCampo(pista: compacto ? null : 'SC-02418'),
            textCapitalization: TextCapitalization.characters,
            validator: requerido,
          ),
        ),
        CampoEtiquetado(
          etiqueta: etiquetaDocumento,
          child: FormField<String>(
            validator: requerido,
            builder: (campo) => InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () async {
                final archivo = await elegir();
                if (archivo == null) return;
                campo.didChange(archivo);
                alElegirDocumento(archivo);
              },
              child: InputDecorator(
                decoration: decoracionCampo().copyWith(
                  errorText: campo.errorText,
                  prefixIcon: compacto ? const Icon(Icons.upload_outlined, size: 18, color: colorVerde) : null,
                ),
                child: Text(
                  campo.value == null ? 'Elegir archivo' : '${campo.value} ✓',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 5. Muestra un recuadro verde con información sobre el rol.
class AvisoRol extends StatelessWidget {
  const AvisoRol({super.key, required this.titulo, required this.texto});

  final String titulo;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: colorVerdeSuave, borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: tema.labelLarge?.copyWith(color: colorVerdeOscuro, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(texto, style: tema.bodySmall?.copyWith(color: colorTextoSuave)),
        ],
      ),
    );
  }
}
