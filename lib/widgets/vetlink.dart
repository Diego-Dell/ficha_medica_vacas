import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

// 1. Colores del manual de marca (mismos que el diseño original).
const colorVerde = Color(0xFF2F5D46);
const colorVerdeOscuro = Color(0xFF24402F);
const colorVerdeSuave = Color(0xFFE6EBDF);
const colorFondo = Color(0xFFF6F7F0);
const colorSuperficie = Colors.white;
const colorBorde = Color(0xFFDDE1D6);
const colorTextoSuave = Color(0xFF5F6B60);
const colorAmbarFondo = Color(0xFFFCEFD9);
const colorAmbarTexto = Color(0xFF9A5B13);
const colorRojo = Color(0xFFA2453D);
const colorRojoFondo = Color(0xFFF6E4E1);

// 2. Tipografías: títulos y texto.
const fuenteTitulos = 'PlusJakartaSans';
const fuenteTexto = 'Figtree';

// 3. Radios y sombra de tarjeta.
const radioCampo = 12.0;
const radioTarjeta = 16.0;
const sombraTarjeta = [BoxShadow(color: Color(0x1424402F), blurRadius: 12, offset: Offset(0, 2))];

/// 1. Tema de la app con la tipografía y los colores de la marca.
ThemeData temaVetLink() {
  final base = ThemeData(colorSchemeSeed: colorVerde, useMaterial3: true, fontFamily: fuenteTexto);
  TextStyle? titulo(TextStyle? s, double tam, FontWeight peso) =>
      s?.copyWith(fontFamily: fuenteTitulos, fontSize: tam, fontWeight: peso, color: colorVerdeOscuro);
  final t = base.textTheme;
  return base.copyWith(
    scaffoldBackgroundColor: colorFondo,
    textTheme: t.copyWith(
      headlineMedium: titulo(t.headlineMedium, 28, FontWeight.w800),
      headlineSmall: titulo(t.headlineSmall, 24, FontWeight.w700),
      titleLarge: titulo(t.titleLarge, 20, FontWeight.w700),
      titleMedium: titulo(t.titleMedium, 16, FontWeight.w700),
      bodyLarge: t.bodyLarge?.copyWith(fontSize: 15, color: colorVerdeOscuro),
      bodyMedium: t.bodyMedium?.copyWith(fontSize: 14, color: colorVerdeOscuro),
      bodySmall: t.bodySmall?.copyWith(fontSize: 12, color: colorTextoSuave),
      labelLarge: t.labelLarge?.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
      labelMedium: t.labelMedium?.copyWith(fontSize: 13, fontWeight: FontWeight.w600, color: colorVerdeOscuro),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: colorVerdeOscuro,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(radioTarjeta))),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: colorSuperficie,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(24))),
    ),
  );
}

/// 2. Valida que un campo obligatorio tenga texto.
String? requerido(String? valor) => (valor == null || valor.trim().isEmpty) ? 'Campo obligatorio' : null;

// Validaciones de entrada comunes a todos los módulos (casos de uso).
final _correo = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');
String? correoValido(String? valor) =>
    requerido(valor) ?? (_correo.hasMatch(valor!.trim()) ? null : 'Ingresá un correo válido');

String? Function(String?) textoEntre(int minimo, int maximo) => (valor) {
  final texto = valor?.trim() ?? '';
  if (texto.isEmpty) return 'Campo obligatorio';
  if (texto.length < minimo) return 'Escribí al menos $minimo caracteres';
  if (texto.length > maximo) return 'Máximo $maximo caracteres';
  return null;
};

String? Function(String?) textoOpcional(int maximo) =>
    (valor) => (valor?.trim().length ?? 0) > maximo ? 'Máximo $maximo caracteres' : null;

/// 3. Muestra un mensaje y reemplaza el anterior.
void avisar(BuildContext context, String mensaje) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(mensaje)));
}

/// 4. Escribe una fecha como dd/mm/aaaa.
String fechaCorta(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

/// 5. Ícono de coolicons (assets/icons) pintado del color pedido.
class Icono extends StatelessWidget {
  const Icono(this.nombre, {super.key, this.color = colorVerdeOscuro, this.tam = 24});

  final String nombre;
  final Color color;
  final double tam;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
        'assets/icons/$nombre.svg',
        width: tam,
        height: tam,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      );
}

/// 6. Burbuja verde suave con un ícono, usada en tarjetas y accesos.
class BurbujaIcono extends StatelessWidget {
  const BurbujaIcono(this.icono, {super.key, this.tam = 44, this.fondo = colorVerdeSuave, this.color = colorVerde});

  final String icono;
  final double tam;
  final Color fondo, color;

  @override
  Widget build(BuildContext context) => Container(
        width: tam,
        height: tam,
        decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(radioCampo)),
        alignment: Alignment.center,
        child: Icono(icono, color: color, tam: tam / 2),
      );
}

/// 7. Aplica el estilo del diseño a un campo de formulario.
InputDecoration decoracionCampo({String? pista, String? icono}) {
  OutlineInputBorder borde(Color color, [double ancho = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(radioCampo),
        borderSide: BorderSide(color: color, width: ancho),
      );
  return InputDecoration(
    hintText: pista,
    hintStyle: const TextStyle(color: colorTextoSuave),
    filled: true,
    fillColor: colorSuperficie,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
    prefixIcon: icono == null ? null : Padding(padding: const EdgeInsets.all(14), child: Icono(icono, color: colorTextoSuave, tam: 20)),
    enabledBorder: borde(colorBorde),
    focusedBorder: borde(colorVerde, 1.5),
    errorBorder: borde(colorRojo),
    focusedErrorBorder: borde(colorRojo, 1.5),
  );
}

/// 8. Botón circular para volver.
class BotonVolver extends StatelessWidget {
  const BotonVolver({super.key, required this.alPresionar});

  final VoidCallback alPresionar;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: 'Volver',
        child: Material(
          color: colorSuperficie,
          shape: const CircleBorder(side: BorderSide(color: colorBorde)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: alPresionar,
            child: const SizedBox(width: 40, height: 40, child: Center(child: Icono('volver', tam: 20))),
          ),
        ),
      );
}

/// 9. Encabezado interno: volver (o logo), título y granja.
class Cabecera extends StatelessWidget {
  const Cabecera({super.key, required this.titulo, this.detalle, this.alVolver});

  final String titulo;
  final String? detalle;
  final VoidCallback? alVolver;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          if (alVolver != null)
            BotonVolver(alPresionar: alVolver!)
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset('assets/images/logo.png', width: 40, height: 40),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, maxLines: 1, overflow: TextOverflow.ellipsis, style: tema.titleMedium),
                if (detalle != null)
                  Text(detalle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: tema.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 10. Datos del encabezado de una pantalla interna: granja, rol y volver.
class EncabezadoVetLink {
  const EncabezadoVetLink({this.granja, this.rol, this.alVolver});

  final String? granja;
  final String? rol;
  final VoidCallback? alVolver;
}

/// 11. Base de cada pantalla: encabezado, subtítulo, contenido y barra opcional.
class PantallaVetLink extends StatelessWidget {
  const PantallaVetLink({
    super.key,
    required this.children,
    this.titulo,
    this.subtitulo,
    this.encabezado = const EncabezadoVetLink(),
    this.barraInferior,
    this.botonFlotante,
  });

  final String? titulo;
  final String? subtitulo;
  final EncabezadoVetLink encabezado;
  final Widget? barraInferior;
  final Widget? botonFlotante;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => MarcoPantalla(
        titulo: titulo ?? 'VetLink',
        detalle: encabezado.granja ?? encabezado.rol ?? 'VetLink',
        subtitulo: subtitulo,
        alVolver: encabezado.alVolver,
        barraInferior: barraInferior,
        botonFlotante: botonFlotante,
        children: children,
      );
}

/// 12. Marco común: encabezado fijo y contenido con scroll.
class MarcoPantalla extends StatelessWidget {
  const MarcoPantalla({
    super.key,
    required this.titulo,
    required this.children,
    this.detalle,
    this.subtitulo,
    this.alVolver,
    this.barraInferior,
    this.botonFlotante,
    this.menuLateral,
  });

  final String titulo;
  final String? detalle, subtitulo;
  final VoidCallback? alVolver;
  final Widget? barraInferior, botonFlotante, menuLateral;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: colorFondo,
        endDrawer: menuLateral,
        bottomNavigationBar: barraInferior,
        floatingActionButton: botonFlotante,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Cabecera(titulo: titulo, detalle: detalle, alVolver: alVolver),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(16, 8, 16, botonFlotante == null ? 24 : 96),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (subtitulo != null) ...[
                            Text(subtitulo!, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colorTextoSuave)),
                            const SizedBox(height: 16),
                          ],
                          ...children,
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

/// 13. Muestra un campo de formulario con su etiqueta arriba.
class CampoEtiquetado extends StatelessWidget {
  const CampoEtiquetado({super.key, required this.etiqueta, required this.child});

  final String etiqueta;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(etiqueta, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

final _formaBoton = RoundedRectangleBorder(borderRadius: BorderRadius.circular(radioTarjeta));

/// 14. Botón con la acción principal de la pantalla.
class BotonPrincipal extends StatelessWidget {
  const BotonPrincipal({super.key, required this.texto, required this.alPresionar, this.color = colorVerde});

  final String texto;
  final VoidCallback? alPresionar;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: color,
          minimumSize: const Size.fromHeight(52),
          shape: _formaBoton,
          textStyle: const TextStyle(fontFamily: fuenteTexto, fontSize: 15, fontWeight: FontWeight.w600),
        ),
        onPressed: alPresionar,
        child: Text(texto),
      ),
    );
  }
}

/// 15. Botón blanco de las acciones secundarias.
class BotonSecundario extends StatelessWidget {
  const BotonSecundario({super.key, required this.texto, required this.alPresionar});

  final String texto;
  final VoidCallback? alPresionar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorVerdeOscuro,
          backgroundColor: colorSuperficie,
          minimumSize: const Size.fromHeight(52),
          side: const BorderSide(color: colorBorde),
          shape: _formaBoton,
          textStyle: const TextStyle(fontFamily: fuenteTexto, fontSize: 15, fontWeight: FontWeight.w600),
        ),
        onPressed: alPresionar,
        child: Text(texto),
      ),
    );
  }
}

/// 16. Tarjeta blanca con sombra suave; con [alPresionar] es tocable.
class Tarjeta extends StatelessWidget {
  const Tarjeta({super.key, required this.child, this.alPresionar, this.relleno = const EdgeInsets.all(16)});

  final Widget child;
  final VoidCallback? alPresionar;
  final EdgeInsets relleno;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(radioTarjeta), boxShadow: sombraTarjeta),
        child: Material(
          color: colorSuperficie,
          borderRadius: BorderRadius.circular(radioTarjeta),
          clipBehavior: Clip.antiAlias,
          child: InkWell(onTap: alPresionar, child: Padding(padding: relleno, child: child)),
        ),
      );
}

/// 17. Tipo de etiqueta de estado.
enum TipoChip { exito, neutro, advertencia, error }

/// 18. Etiqueta corta de estado: Activa, De baja, Pendiente...
class ChipEstado extends StatelessWidget {
  const ChipEstado(this.texto, {super.key, this.tipo = TipoChip.exito});

  final String texto;
  final TipoChip tipo;

  @override
  Widget build(BuildContext context) {
    final (fondo, tinta) = switch (tipo) {
      TipoChip.exito => (colorVerdeSuave, colorVerde),
      TipoChip.neutro => (colorSuperficie, colorTextoSuave),
      TipoChip.advertencia => (colorAmbarFondo, colorAmbarTexto),
      TipoChip.error => (colorRojoFondo, colorRojo),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(999),
        border: tipo == TipoChip.neutro ? Border.all(color: colorBorde) : null,
      ),
      child: Text(texto, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: tinta)),
    );
  }
}

/// 19. Mensaje en línea con ícono: información, advertencia o peligro.
class AvisoVetLink extends StatelessWidget {
  const AvisoVetLink({super.key, required this.titulo, this.texto, this.advertencia = false, this.peligro = false});

  final String titulo;
  final String? texto;
  final bool advertencia, peligro;

  @override
  Widget build(BuildContext context) {
    final tinta = peligro ? colorRojo : (advertencia ? colorAmbarTexto : colorVerde);
    final fondo = peligro ? colorRojoFondo : (advertencia ? colorAmbarFondo : colorVerdeSuave);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(radioCampo),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icono((peligro || advertencia) ? 'alerta' : 'info', color: tinta, tam: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tinta)),
                if (texto != null) ...[
                  const SizedBox(height: 2),
                  Text(texto!, style: TextStyle(fontSize: 13, height: 1.35, color: tinta)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 20. Ventana de confirmación o resultado: ícono, título, texto y acciones.
class VentanaVetLink extends StatelessWidget {
  const VentanaVetLink({
    super.key,
    required this.icono,
    required this.titulo,
    required this.acciones,
    this.texto,
    this.peligro = false,
  });

  final String icono, titulo;
  final String? texto;
  final bool peligro;
  final List<Widget> acciones;

  @override
  Widget build(BuildContext context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 32),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: peligro ? colorRojoFondo : colorVerdeSuave),
                  alignment: Alignment.center,
                  child: Icono(icono, color: peligro ? colorRojo : colorVerde, tam: 28),
                ),
              ),
              const SizedBox(height: 14),
              Text(titulo, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
              if (texto != null) ...[
                const SizedBox(height: 8),
                Text(texto!, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 13)),
              ],
              const SizedBox(height: 18),
              ...acciones,
            ],
          ),
        ),
      );
}
