import 'package:flutter/material.dart';

const colorVerde = Color(0xFF2F5D46);
const colorVerdeOscuro = Color(0xFF24402F);
const colorVerdeSuave = Color(0xFFE6EBDF);
const colorFondo = Color(0xFFF6F7F0);
const colorBorde = Color(0xFFDDE1D6);
const colorTextoSuave = Color(0xFF5F6B60);
const colorAmbarFondo = Color(0xFFFCEFD9);
const colorAmbarTexto = Color(0xFF9A5B13);
const colorRojo = Color(0xFFA2453D);

final _forma = RoundedRectangleBorder(borderRadius: BorderRadius.circular(10));

String? requerido(String? valor) => (valor == null || valor.trim().isEmpty) ? 'Campo obligatorio' : null;

void avisar(BuildContext context, String mensaje) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(mensaje)));
}

InputDecoration decoracionCampo({String? pista}) {
  OutlineInputBorder borde(Color color) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: color),
      );
  return InputDecoration(
    hintText: pista,
    filled: true,
    fillColor: Colors.white,
    enabledBorder: borde(colorBorde),
    focusedBorder: borde(colorVerde),
    errorBorder: borde(Colors.red.shade700),
    focusedErrorBorder: borde(Colors.red.shade700),
  );
}

/// Base de todas las pantallas: encabezado con la marca, contenido y barra inferior opcional.
class PantallaVetLink extends StatelessWidget {
  const PantallaVetLink({
    super.key,
    required this.children,
    this.titulo,
    this.subtitulo,
    this.encabezado = const EncabezadoVetLink(),
    this.barraInferior,
  });

  final String? titulo;
  final String? subtitulo;
  final Widget encabezado;
  final Widget? barraInferior;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: colorFondo,
      bottomNavigationBar: barraInferior,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  encabezado,
                  const SizedBox(height: 24),
                  if (titulo != null)
                    Text(
                      titulo!,
                      style: tema.headlineSmall?.copyWith(color: colorVerdeOscuro, fontWeight: FontWeight.w700),
                    ),
                  if (subtitulo != null) ...[
                    const SizedBox(height: 6),
                    Text(subtitulo!, style: tema.bodyMedium?.copyWith(color: colorTextoSuave)),
                  ],
                  const SizedBox(height: 10),
                  ...children,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Barra inferior de las pantallas de una granja. Con [alVolver] la primera opción regresa en vez de ser "Inicio".
class BarraVetLink extends StatelessWidget {
  const BarraVetLink({super.key, this.alVolver});

  final VoidCallback? alVolver;

  @override
  Widget build(BuildContext context) {
    Widget opcion(String texto, VoidCallback? alPresionar) => Expanded(
          child: TextButton(
            style: TextButton.styleFrom(foregroundColor: colorVerdeOscuro),
            onPressed: alPresionar,
            child: Text(texto, style: const TextStyle(fontSize: 12)),
          ),
        );
    void pronto(String funcion) => avisar(context, '$funcion estará disponible pronto');

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: colorBorde)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            alVolver == null ? opcion('Inicio', null) : opcion('‹ Volver', alVolver),
            opcion('Avisos', () => pronto('Avisos')),
            opcion('Reportes', () => pronto('Reportes')),
            opcion('Más', () => pronto('Más')),
          ],
        ),
      ),
    );
  }
}

/// Logo y nombre de la app. Con [granja] también muestra la granja actual y, con [alVolver], el enlace de regreso.
class EncabezadoVetLink extends StatelessWidget {
  const EncabezadoVetLink({super.key, this.granja, this.rol, this.alVolver});

  final String? granja;
  final String? rol;
  final VoidCallback? alVolver;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(color: colorVerde, borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.eco_outlined, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'VetLink',
                    style: tema.titleSmall?.copyWith(color: colorVerdeOscuro, fontWeight: FontWeight.w600),
                  ),
                  if (granja != null) Text(granja!, style: tema.labelSmall?.copyWith(color: colorTextoSuave)),
                ],
              ),
            ),
            if (alVolver != null)
              TextButton(
                onPressed: alVolver,
                style: TextButton.styleFrom(foregroundColor: colorVerde),
                child: const Text('‹ Volver'),
              ),
          ],
        ),
        if (rol != null) ...[
          const SizedBox(height: 4),
          Text(rol!, style: tema.labelSmall?.copyWith(color: colorVerdeOscuro)),
        ],
      ],
    );
  }
}

/// Campo de formulario con su etiqueta arriba.
class CampoEtiquetado extends StatelessWidget {
  const CampoEtiquetado({super.key, required this.etiqueta, required this.child});

  final String etiqueta;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(etiqueta, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: colorVerdeOscuro)),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

class BotonPrincipal extends StatelessWidget {
  const BotonPrincipal({super.key, required this.texto, required this.alPresionar, this.color = colorVerde});

  final String texto;
  final VoidCallback? alPresionar;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: color,
          minimumSize: const Size.fromHeight(48),
          shape: _forma,
        ),
        onPressed: alPresionar,
        child: Text(texto),
      ),
    );
  }
}

class BotonSecundario extends StatelessWidget {
  const BotonSecundario({super.key, required this.texto, required this.alPresionar});

  final String texto;
  final VoidCallback? alPresionar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorVerde,
          backgroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
          side: const BorderSide(color: colorBorde),
          shape: _forma,
        ),
        onPressed: alPresionar,
        child: Text(texto),
      ),
    );
  }
}
