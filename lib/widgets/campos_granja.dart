import '../logic/documentos.dart';

import 'package:flutter/material.dart';

import 'vetlink.dart';

/// 1. Conserva el documento elegido para subirlo con una sesión confirmada.
Future<String?> elegirDocumento() => Documentos.elegir();

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
    this.documentoInicial,
  });

  final bool compacto;
  final TextEditingController nombre;
  final TextEditingController superficie;
  final TextEditingController runsa;
  final ValueChanged<String> alElegirDocumento;
  final Future<String?> Function() elegir;
  final String etiquetaNombre;
  final String etiquetaDocumento;
  final String? documentoInicial;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CampoEtiquetado(
          etiqueta: etiquetaNombre,
          child: TextFormField(
            controller: nombre,
            decoration: decoracionCampo(pista: compacto ? null : 'Los Pinos', icono: 'granja'),
            textCapitalization: TextCapitalization.words,
            validator: textoEntre(2, 120),
          ),
        ),
        CampoEtiquetado(
          etiqueta: 'Superficie (hectáreas) *',
          child: TextFormField(
            controller: superficie,
            decoration: decoracionCampo(pista: compacto ? null : '18', icono: 'ubicacion'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: superficieValida,
          ),
        ),
        CampoEtiquetado(
          etiqueta: 'RUNSA *',
          child: TextFormField(
            controller: runsa,
            decoration: decoracionCampo(pista: compacto ? null : 'SC-02418', icono: 'documento'),
            textCapitalization: TextCapitalization.characters,
            validator: textoEntre(3, 30),
          ),
        ),
        CampoEtiquetado(
          etiqueta: etiquetaDocumento,
          child: FormField<String>(
            initialValue: documentoInicial,
            validator: (valor) => requerido(valor) ?? (valor!.toLowerCase().endsWith('.pdf') ? null : 'Adjuntá un PDF'),
            builder: (campo) => InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () async {
                try {
                  final archivo = await elegir();
                  if (archivo == null || !campo.mounted) return;
                  campo.didChange(archivo);
                  alElegirDocumento(archivo);
                } on FormatException catch (error) {
                  if (context.mounted) avisar(context, error.message);
                } on Exception {
                  if (context.mounted) avisar(context, 'No se pudo leer el archivo. Elegí otro documento');
                }
              },
              child: InputDecorator(
                decoration: decoracionCampo().copyWith(
                  errorText: campo.errorText,
                  prefixIcon: compacto ? const Icon(Icons.upload_outlined, size: 18, color: colorVerde) : null,
                ),
                child: Text(
                  campo.value == null ? 'Elegir PDF (hasta 10 MB)' : '${Documentos.nombre(campo.value!)} ✓',
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

  // 1. Usa el aviso informativo del manual de marca.
  @override
  Widget build(BuildContext context) => AvisoVetLink(titulo: titulo, texto: texto);
}
