import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';

import '../logic/granjas.dart';
import '../logic/reportes.dart';
import '../models/animal.dart';
import '../widgets/vetlink.dart';

typedef DescargadorPdf = Future<String?> Function(String nombreArchivo, Uint8List bytes);

Future<String?> _guardarPdfPredeterminado(String nombreArchivo, Uint8List bytes) async {
  try {
    final uri = await FilePicker.saveFile(
      dialogTitle: 'Guardar reporte PDF',
      fileName: nombreArchivo,
      bytes: bytes,
      mimeType: 'application/pdf',
    );
    if (uri != null) return uri.toString();
  } on Object {
    /* En entornos sin selector gráfico se guarda en la carpeta local de la app. */
  }
  Directory? carpeta;
  try {
    carpeta = await getDownloadsDirectory();
  } on Object {
    carpeta = null;
  }
  carpeta ??= await getApplicationDocumentsDirectory();
  final archivo = File('${carpeta.path}/$nombreArchivo');
  await archivo.writeAsBytes(bytes, flush: true);
  return archivo.path;
}

void _mostrarToastPdfDescargado(BuildContext context, ReporteGenerado reporte) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        shape: const StadiumBorder(),
        backgroundColor: colorVerdeOscuro,
        behavior: SnackBarBehavior.floating,
        content: const Row(
          children: [
            Icono('descargar', color: Colors.white, tam: 18),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'PDF guardado en Descargas',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: 'Abrir',
          textColor: Colors.white,
          onPressed: () {
            if (context.mounted) {
              Navigator.push<void>(
                context,
                MaterialPageRoute(builder: (_) => _VisorPdfScreen(reporte: reporte)),
              );
            }
          },
        ),
      ),
    );
}

Future<void> _compartirPdf(BuildContext context, ReporteGenerado reporte) async {
  try {
    await Printing.sharePdf(
      bytes: reporte.pdf,
      filename: reporte.nombreArchivo,
    );
  } on Object {
    if (context.mounted) {
      avisar(context, 'Usá Descargar PDF para guardar el archivo en tu dispositivo');
    }
  }
}

ButtonStyle _estiloBotonBlanco() => OutlinedButton.styleFrom(
      foregroundColor: colorVerdeOscuro,
      backgroundColor: colorSuperficie,
      minimumSize: const Size.fromHeight(52),
      side: const BorderSide(color: colorBorde),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radioTarjeta)),
      textStyle: const TextStyle(fontFamily: fuenteTexto, fontSize: 15, fontWeight: FontWeight.w600),
    );

ButtonStyle _estiloBotonVerde() => FilledButton.styleFrom(
      backgroundColor: colorVerde,
      minimumSize: const Size.fromHeight(52),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radioTarjeta)),
      textStyle: const TextStyle(fontFamily: fuenteTexto, fontSize: 15, fontWeight: FontWeight.w600),
    );

/// 1. Pantalla Generar reportes (RF-08), fiel al diseño de Figma:
///    selector de periodo (Semana / Mes / Año), grilla 2x2 de KPIs,
///    botón Descargar reporte y tarjetas de reportes en PDF.
class ReportesScreen extends StatefulWidget {
  const ReportesScreen({
    super.key,
    this.enPestana = false,
    this.alVolver,
    this.alDescargar,
  });

  final bool enPestana;
  final VoidCallback? alVolver;

  /// Permite inyectar la descarga en pruebas sin canales nativos.
  final DescargadorPdf? alDescargar;

  @override
  State<ReportesScreen> createState() => _ReportesScreenState();
}

class _ReportesScreenState extends State<ReportesScreen> {
  PeriodoReporte _periodo = PeriodoReporte.mes;
  ReporteGranjaDatos? _datos;
  Animal? _animal;
  bool _cargando = true;
  bool _ocupado = false;
  String? _errorCarga;
  String? _error;
  String? _granjaId;

  @override
  void initState() {
    super.initState();
    _granjaId = Granjas.instance.seleccionada?.id;
    _cargarResumen();
  }

  @override
  void didUpdateWidget(covariant ReportesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final actualId = Granjas.instance.seleccionada?.id;
    if (actualId != _granjaId) {
      _granjaId = actualId;
      _animal = null;
      _cargarResumen();
    }
  }

  Future<void> _cargarResumen() async {
    if (!Reportes.instance.puedeGenerar || Granjas.instance.seleccionada == null) {
      if (mounted) {
        setState(() {
          _cargando = false;
          _datos = null;
        });
      }
      return;
    }
    setState(() {
      _cargando = true;
      _errorCarga = null;
      _error = null;
    });
    try {
      final datos = await Reportes.instance.cargarVistaGranja(periodo: _periodo);
      if (!mounted) return;
      setState(() {
        _datos = datos;
        _cargando = false;
        if (_animal != null && !datos.animales.any((a) => a.id == _animal!.id)) {
          _animal = null;
        }
      });
    } on FalloReporte catch (e) {
      if (mounted) {
        setState(() {
          _errorCarga = e.mensaje;
          _cargando = false;
        });
      }
    } on Exception {
      if (mounted) {
        setState(() {
          _errorCarga = 'No se pudieron cargar los datos de la granja. Revisá tu conexión e intentá nuevamente.';
          _cargando = false;
        });
      }
    }
  }

  void _cambiarPeriodo(PeriodoReporte periodo) {
    if (_ocupado || _periodo == periodo) return;
    setState(() {
      _periodo = periodo;
      _datos = _datos?.conPeriodo(periodo);
      _error = null;
    });
  }

  Future<void> _ejecutarReporte(Future<void> Function() accion, String mensajeError) async {
    if (_ocupado) return;
    if (!Reportes.instance.puedeGenerar) {
      setState(() => _error = 'Solo el dueño, administrador o veterinario pueden generar reportes sanitarios.');
      return;
    }
    setState(() {
      _ocupado = true;
      _error = null;
    });
    try {
      await accion();
    } on FalloReporte catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } on Exception {
      if (mounted) setState(() => _error = mensajeError);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _abrirVistaPrevia(ReporteGenerado reporte) async {
    if (!mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => VistaPreviaReporteScreen(
          reporte: reporte,
          alDescargar: widget.alDescargar,
        ),
      ),
    );
  }

  Future<void> _descargarResumenDirecto() => _ejecutarReporte(() async {
        final reporte = await Reportes.instance.generarResumenGranja(
          periodo: _periodo,
          datosPrevios: _datos,
        );
        final descargador = widget.alDescargar ?? _guardarPdfPredeterminado;
        await descargador(reporte.nombreArchivo, reporte.pdf);
        if (mounted) _mostrarToastPdfDescargado(context, reporte);
      }, 'No se pudo descargar el reporte PDF. Intentá nuevamente.');

  Future<void> _abrirResumenPreview() => _ejecutarReporte(() async {
        final reporte = await Reportes.instance.generarResumenGranja(
          periodo: _periodo,
          datosPrevios: _datos,
        );
        await _abrirVistaPrevia(reporte);
      }, 'No se pudo generar el reporte. Revisá los datos e intentá nuevamente.');

  Future<void> _elegirAnimalYVer() async {
    if (_ocupado) return;
    if (_errorCarga != null) {
      setState(() => _error = _errorCarga);
      return;
    }
    if (_cargando && _datos == null) {
      await _cargarResumen();
      if (!mounted || _errorCarga != null) {
        if (mounted && _errorCarga != null) setState(() => _error = _errorCarga);
        return;
      }
    }
    final animales = _datos?.animales ?? const <Animal>[];
    if (animales.isEmpty) {
      setState(() {
        _error = 'Registrá al menos un animal en la granja para generar el historial sanitario.';
      });
      return;
    }

    final elegido = await showModalBottomSheet<Animal>(
      context: context,
      showDragHandle: true,
      backgroundColor: colorSuperficie,
      isScrollControlled: true,
      builder: (_) => _SelectorAnimalReporteSheet(
        granjaNombre: _datos?.granja.nombre ?? Granjas.instance.actual.nombre,
        animales: animales,
        actual: _animal,
      ),
    );
    if (!mounted || elegido == null) return;

    setState(() => _animal = elegido);
    await _ejecutarReporte(() async {
      final reporte = await Reportes.instance.generarHistorialAnimal(elegido);
      await _abrirVistaPrevia(reporte);
    }, 'No se pudo generar el historial del animal. Intentá nuevamente.');
  }

  Widget _selectorPeriodo() => Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: colorSuperficie,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: colorBorde),
          boxShadow: sombraTarjeta,
        ),
        child: Row(
          children: [
            for (final periodo in PeriodoReporte.values)
              Expanded(
                child: Material(
                  color: _periodo == periodo ? colorVerde : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: _ocupado ? null : () => _cambiarPeriodo(periodo),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text(
                        periodo.etiqueta,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _periodo == periodo ? Colors.white : colorTextoSuave,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );

  Widget _tarjetaKpi({
    required String icono,
    required String valor,
    required String etiqueta,
    bool alertaRoja = false,
  }) =>
      Tarjeta(
        relleno: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BurbujaIcono(
              icono,
              tam: 36,
              fondo: alertaRoja ? colorRojoFondo : colorVerdeSuave,
              color: alertaRoja ? colorRojo : colorVerde,
            ),
            const SizedBox(height: 12),
            Text(
              valor,
              style: TextStyle(
                fontFamily: fuenteTitulos,
                fontSize: 28,
                fontWeight: FontWeight.w700,
                height: 1.0,
                color: alertaRoja ? colorRojo : colorVerdeOscuro,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              etiqueta,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );

  Widget _tarjetaPdf({
    required String icono,
    required String titulo,
    required String subtitulo,
    required VoidCallback? alPresionar,
  }) =>
      Tarjeta(
        alPresionar: alPresionar,
        relleno: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            BurbujaIcono(icono, tam: 42),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 14.5),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Ver',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colorVerde),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final granja = Granjas.instance.seleccionada;
    final granjaNombre = granja?.nombre ?? 'VetLink';

    if (!Reportes.instance.puedeGenerar) {
      return PantallaVetLink(
        encabezado: EncabezadoVetLink(
          granja: granjaNombre,
          alVolver: widget.alVolver ?? () => Navigator.maybePop(context),
        ),
        titulo: 'Generar reportes',
        children: [
          const SizedBox(height: 12),
          const AvisoVetLink(
            titulo: 'Acceso restringido',
            texto: 'Solo el dueño, administrador o veterinario pueden generar los reportes sanitarios.',
            peligro: true,
          ),
          if (!widget.enPestana)
            BotonSecundario(
              texto: 'Volver',
              alPresionar: () => Navigator.maybePop(context),
            ),
        ],
      );
    }

    final datos = _datos;
    final animales = datos?.animales ?? const <Animal>[];
    final bajas = datos?.bajasPeriodo ?? 0;
    final subtituloPeriodo = '$granjaNombre · ${_periodo.subtitulo(referencia: datos?.generadoEn)}';
    final subtituloAnimal = _animal != null
        ? _animal!.titulo
        : animales.isNotEmpty
            ? 'Ejemplo: ${animales.first.titulo}'
            : _errorCarga != null
                ? 'No se pudieron cargar los animales'
                : _cargando
                    ? 'Cargando animales...'
                    : 'Sin animales registrados';

    return PantallaVetLink(
      encabezado: EncabezadoVetLink(
        granja: granjaNombre,
        alVolver: _ocupado ? null : (widget.alVolver ?? () => Navigator.maybePop(context)),
      ),
      titulo: 'Generar reportes',
      children: [
        const SizedBox(height: 4),
        _selectorPeriodo(),
        if (_errorCarga != null) ...[
          AvisoVetLink(
            titulo: 'No se pudieron cargar los datos de la granja',
            texto: _errorCarga!,
            peligro: true,
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              style: TextButton.styleFrom(foregroundColor: colorRojo),
              onPressed: _cargando ? null : _cargarResumen,
              child: const Text('Reintentar carga'),
            ),
          ),
        ],
        Row(
          children: [
            Expanded(
              child: _tarjetaKpi(
                icono: 'ganado',
                valor: _cargando && datos == null ? '–' : '${datos?.activos.length ?? 0}',
                etiqueta: 'Animales activos',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _tarjetaKpi(
                icono: 'clinica',
                valor: _cargando && datos == null ? '–' : '${datos?.atencionesPeriodo ?? 0}',
                etiqueta: 'Atenciones',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _tarjetaKpi(
                icono: 'vacuna',
                valor: _cargando && datos == null ? '–' : '${datos?.vacunasAplicadasPeriodo ?? 0}',
                etiqueta: 'Vacunas aplicadas',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _tarjetaKpi(
                icono: 'alerta',
                valor: _cargando && datos == null ? '–' : '$bajas',
                etiqueta: _periodo.etiquetaBajas,
                alertaRoja: bajas > 0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_error != null && _error != _errorCarga)
          AvisoVetLink(
            titulo: 'No se pudo generar el reporte',
            texto: _error!,
            peligro: true,
          ),
        if (_ocupado)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: LinearProgressIndicator(
              color: colorVerde,
              backgroundColor: colorVerdeSuave,
            ),
          ),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radioTarjeta),
            boxShadow: sombraTarjeta,
          ),
          child: OutlinedButton(
            style: _estiloBotonBlanco(),
            onPressed: _ocupado ? null : _descargarResumenDirecto,
            child: Text(_ocupado ? 'Preparando PDF...' : 'Descargar reporte'),
          ),
        ),
        const SizedBox(height: 22),
        Text('Reportes en PDF', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        _tarjetaPdf(
          icono: 'documento',
          titulo: TipoReporte.resumenGranja.etiqueta,
          subtitulo: subtituloPeriodo,
          alPresionar: _ocupado ? null : _abrirResumenPreview,
        ),
        const SizedBox(height: 12),
        _tarjetaPdf(
          icono: 'ganado',
          titulo: TipoReporte.historialAnimal.etiqueta,
          subtitulo: subtituloAnimal,
          alPresionar: _ocupado ? null : _elegirAnimalYVer,
        ),
      ],
    );
  }
}

class _SelectorAnimalReporteSheet extends StatefulWidget {
  const _SelectorAnimalReporteSheet({
    required this.granjaNombre,
    required this.animales,
    this.actual,
  });

  final String granjaNombre;
  final List<Animal> animales;
  final Animal? actual;

  @override
  State<_SelectorAnimalReporteSheet> createState() => _SelectorAnimalReporteSheetState();
}

class _SelectorAnimalReporteSheetState extends State<_SelectorAnimalReporteSheet> {
  String _busqueda = '';

  @override
  Widget build(BuildContext context) {
    final filtrados = widget.animales.where((a) {
      if (_busqueda.isEmpty) return true;
      return '${a.arete} ${a.nombre ?? ''} ${a.etapa.etiqueta}'
          .toLowerCase()
          .contains(_busqueda);
    }).toList();

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.72),
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 4, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Seleccionar animal', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                'Elegí un animal de ${widget.granjaNombre} para ver su historial sanitario en PDF.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (widget.animales.length > 3) ...[
                const SizedBox(height: 12),
                TextField(
                  decoration: decoracionCampo(pista: 'Buscar por arete o nombre', icono: 'buscar'),
                  onChanged: (v) => setState(() => _busqueda = v.trim().toLowerCase()),
                ),
              ],
              const SizedBox(height: 12),
              Flexible(
                child: filtrados.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Text('No hay animales con ese criterio.', textAlign: TextAlign.center),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: filtrados.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final a = filtrados[i];
                          final elegido = widget.actual?.id == a.id;
                          return Tarjeta(
                            alPresionar: () => Navigator.pop(context, a),
                            relleno: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            child: Row(
                              children: [
                                BurbujaIcono(
                                  'ganado',
                                  tam: 38,
                                  fondo: a.deBaja
                                      ? colorRojoFondo
                                      : (elegido ? colorVerde : colorVerdeSuave),
                                  color: a.deBaja
                                      ? colorRojo
                                      : (elegido ? Colors.white : colorVerde),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        a.titulo,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: a.deBaja ? colorRojo : colorVerdeOscuro,
                                        ),
                                      ),
                                      Text(
                                        [a.etapa.etiqueta, if (a.raza != null) a.raza!].join(' · '),
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                                if (a.deBaja)
                                  const ChipEstado('De baja', tipo: TipoChip.error)
                                else
                                  const Icono('flecha', color: colorTextoSuave, tam: 18),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 2. Pantalla Vista previa del reporte (RF-08), fiel a Figma:
///    hoja blanca elevada con cabecera VetLink, métricas clave, pie Página 1 de 1
///    y botones inferiores Compartir / Descargar PDF.
class VistaPreviaReporteScreen extends StatefulWidget {
  const VistaPreviaReporteScreen({
    super.key,
    required this.reporte,
    this.alDescargar,
  });

  final ReporteGenerado reporte;
  final DescargadorPdf? alDescargar;

  @override
  State<VistaPreviaReporteScreen> createState() => _VistaPreviaReporteScreenState();
}

class _VistaPreviaReporteScreenState extends State<VistaPreviaReporteScreen> {
  bool _descargando = false;
  bool _mostrarDetalleGranja = false;

  Future<void> _descargar() async {
    if (_descargando) return;
    setState(() => _descargando = true);
    try {
      final descargador = widget.alDescargar ?? _guardarPdfPredeterminado;
      await descargador(widget.reporte.nombreArchivo, widget.reporte.pdf);
      if (mounted) _mostrarToastPdfDescargado(context, widget.reporte);
    } on Exception {
      if (mounted) avisar(context, 'No se pudo descargar el PDF. Intentá nuevamente');
    } finally {
      if (mounted) setState(() => _descargando = false);
    }
  }

  void _abrirVisorPdf() {
    Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => _VisorPdfScreen(reporte: widget.reporte)),
    );
  }

  Widget _filaHoja(String etiqueta, String valor, {Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            Expanded(
              child: Text(
                etiqueta,
                style: TextStyle(fontSize: 14, color: color ?? colorTextoSuave),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              valor,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: color ?? colorVerdeOscuro,
              ),
            ),
          ],
        ),
      );

  Widget _hojaDocumento(ReporteGenerado reporte) {
    final tema = Theme.of(context).textTheme;
    final esResumen = reporte.tipo == TipoReporte.resumenGranja;
    final dGranja = reporte.datosGranja;
    final dAnimal = reporte.datosAnimal;

    return Tarjeta(
      alPresionar: _abrirVisorPdf,
      relleno: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset('assets/images/logo.png', width: 28, height: 28),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  esResumen ? 'VetLink · Resumen sanitario' : 'VetLink · Historial sanitario',
                  style: tema.titleMedium?.copyWith(fontSize: 14.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            dGranja != null
                ? 'Granja ${dGranja.granja.nombre} · ${fechaCorta(dGranja.desde)} – ${fechaCorta(dGranja.hasta)}'
                : '${dAnimal!.animal.titulo} · Granja ${dAnimal.granja.nombre}',
            style: tema.bodySmall,
          ),
          const SizedBox(height: 12),
          if (dGranja != null) ...[
            _filaHoja('Animales activos', '${dGranja.activos.length}'),
            _filaHoja('Atenciones clínicas', '${dGranja.atencionesPeriodo}'),
            _filaHoja('Tratamientos activos', '${dGranja.tratamientosActivos}'),
            _filaHoja('Vacunas aplicadas', '${dGranja.vacunasAplicadasPeriodo}'),
            _filaHoja(
              'Controles vencidos',
              '${dGranja.vencidos}',
              color: dGranja.vencidos > 0 ? colorRojo : colorVerdeOscuro,
            ),
            _filaHoja(
              'Bajas',
              '${dGranja.bajasPeriodo}',
              color: dGranja.bajasPeriodo > 0 ? colorRojo : colorVerdeOscuro,
            ),
          ] else if (dAnimal != null) ...[
            _filaHoja(
              'Estado',
              dAnimal.animal.deBaja ? 'De baja' : 'Activo',
              color: dAnimal.animal.deBaja ? colorRojo : colorVerde,
            ),
            _filaHoja('Etapa', dAnimal.animal.etapa.etiqueta),
            _filaHoja('Aptitud reproductiva', dAnimal.valoracion.aptitudTexto),
            _filaHoja('Estado de preñez', dAnimal.valoracion.prenezTexto),
            _filaHoja('Atenciones clínicas', '${dAnimal.atenciones.length}'),
            _filaHoja('Eventos reproductivos', '${dAnimal.reproductivos.length}'),
            _filaHoja('Tratamientos', '${dAnimal.tratamientos.length}'),
            _filaHoja('Prevenciones', '${dAnimal.prevenciones.length}'),
          ],
          const Divider(height: 24, color: colorBorde),
          Row(
            children: [
              Expanded(child: Text('Página 1 de 1', style: tema.bodySmall)),
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: _abrirVisorPdf,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text(
                    'Visualizar PDF',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colorVerde),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _detalleAnimal(ReporteAnimalDatos d) {
    final hoy = DateUtils.dateOnly(d.generadoEn);
    return [
      if (d.animal.deBaja)
        AvisoVetLink(
          titulo: 'Animal dado de baja (${d.animal.fechaBaja != null ? fechaCorta(d.animal.fechaBaja!) : '-'})',
          texto: d.animal.motivoBaja ?? 'Sin motivo registrado',
          peligro: true,
        ),
      for (final aviso in d.advertencias)
        AvisoVetLink(titulo: 'Atención', texto: aviso, advertencia: true),
      Tarjeta(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Atenciones clínicas (${d.atenciones.length})', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (d.atenciones.isEmpty)
              const Text('Sin atenciones clínicas registradas.')
            else
              for (final r in d.atenciones)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${fechaCorta(r.fecha)} · ${r.titulo}',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: r.anulado ? colorRojo : colorVerdeOscuro,
                              ),
                            ),
                          ),
                          if (r.anulado) const ChipEstado('Anulado', tipo: TipoChip.error),
                        ],
                      ),
                      if (r.detalle.isNotEmpty) Text(r.detalle, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      Tarjeta(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Eventos reproductivos (${d.reproductivos.length})', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (d.reproductivos.isEmpty)
              const Text('Sin eventos reproductivos registrados.')
            else
              for (final r in d.reproductivos)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${fechaCorta(r.fecha)} · ${r.titulo}',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: r.anulado ? colorRojo : colorVerdeOscuro,
                              ),
                            ),
                          ),
                          if (r.anulado) const ChipEstado('Anulado', tipo: TipoChip.error),
                        ],
                      ),
                      Text(
                        'Aptitud: ${r.aptitudTexto} · Preñez: ${r.prenezTexto}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (r.detalle.isNotEmpty) Text(r.detalle, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      Tarjeta(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tratamientos (${d.tratamientos.length})', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (d.tratamientos.isEmpty)
              const Text('Sin tratamientos registrados.')
            else
              for (final t in d.tratamientos)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              t.medicamento,
                              style: const TextStyle(fontWeight: FontWeight.w600, color: colorVerdeOscuro),
                            ),
                          ),
                          ChipEstado(
                            t.estado,
                            tipo: t.vigente ? TipoChip.exito : (t.anulado ? TipoChip.error : TipoChip.neutro),
                          ),
                        ],
                      ),
                      Text(
                        '${t.dosis} ${t.unidad} · ${t.via} · ${t.frecuencia} · ${t.duracion}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (t.retiro?.isNotEmpty == true)
                        Text(
                          'Retiro: ${t.retiro}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colorRojo),
                        ),
                    ],
                  ),
                ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      Tarjeta(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Prevención (${d.prevenciones.length})', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (d.prevenciones.isEmpty)
              const Text('Sin prevenciones registradas.')
            else
              for (final p in d.prevenciones)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${p.tipoTexto} · ${p.nombre}',
                              style: const TextStyle(fontWeight: FontWeight.w600, color: colorVerdeOscuro),
                            ),
                            Text('Programada: ${fechaCorta(p.fecha)}', style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                      ),
                      ChipEstado(
                        p.pendiente && DateUtils.dateOnly(p.fecha).isBefore(hoy) ? 'Vencido' : p.estadoTexto,
                        tipo: p.pendiente && DateUtils.dateOnly(p.fecha).isBefore(hoy)
                            ? TipoChip.error
                            : (p.pendiente ? TipoChip.advertencia : TipoChip.exito),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _detalleGranja(ReporteGranjaDatos d) {
    final vencidos = d.vencidos;
    return [
      if (vencidos > 0)
        AvisoVetLink(
          titulo: 'Alerta sanitaria',
          texto: 'Hay $vencidos avisos preventivos vencidos en ${d.granja.nombre}.',
          peligro: true,
        ),
      for (final aviso in d.advertencias)
        AvisoVetLink(titulo: 'Aviso de carga', texto: aviso, advertencia: true),
      Center(
        child: TextButton(
          onPressed: () => setState(() => _mostrarDetalleGranja = !_mostrarDetalleGranja),
          child: Text(_mostrarDetalleGranja ? 'Ocultar detalle' : 'Ver detalle completo'),
        ),
      ),
      if (_mostrarDetalleGranja) ...[
        if (d.avisos.isNotEmpty) ...[
          Tarjeta(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Avisos sanitarios (${d.avisos.length})', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                for (final a in d.avisos)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                a.animal.titulo,
                                style: const TextStyle(fontWeight: FontWeight.w600, color: colorVerdeOscuro),
                              ),
                              Text(
                                '${a.prevencion.tipoTexto} · ${a.prevencion.nombre} (${fechaCorta(a.prevencion.fecha)})',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        ChipEstado(
                          a.vencido ? 'Vencido' : 'Pendiente',
                          tipo: a.vencido ? TipoChip.error : TipoChip.advertencia,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        Tarjeta(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Animales incluidos (${d.animales.length})', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              for (final a in d.animales)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              a.titulo,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: a.deBaja ? colorRojo : colorVerdeOscuro,
                              ),
                            ),
                            Text(
                              '${a.etapa.etiqueta} · Aptitud: ${d.valoraciones[a.id]?.aptitudTexto ?? 'Sin evaluar'} · Preñez: ${d.valoraciones[a.id]?.prenezTexto ?? 'No determinada'}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      ChipEstado(
                        a.deBaja ? 'De baja' : 'Activo',
                        tipo: a.deBaja ? TipoChip.error : TipoChip.exito,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final reporte = widget.reporte;
    final esResumen = reporte.tipo == TipoReporte.resumenGranja;
    final dGranja = reporte.datosGranja;
    final dAnimal = reporte.datosAnimal;
    final detalleCabecera = dGranja != null
        ? '${dGranja.granja.nombre} · ${dGranja.etiquetaPeriodo}'
        : '${dAnimal!.animal.titulo} · ${dAnimal.granja.nombre}';

    return PantallaVetLink(
      encabezado: EncabezadoVetLink(
        granja: detalleCabecera,
        alVolver: () => Navigator.pop(context),
      ),
      titulo: esResumen ? 'Resumen sanitario' : 'Historial sanitario',
      barraInferior: SafeArea(
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(radioTarjeta),
                        boxShadow: sombraTarjeta,
                      ),
                      child: OutlinedButton(
                        style: _estiloBotonBlanco(),
                        onPressed: () => _compartirPdf(context, reporte),
                        child: const Text('Compartir'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      style: _estiloBotonVerde(),
                      onPressed: _descargando ? null : _descargar,
                      child: Text(_descargando ? 'Descargando...' : 'Descargar PDF'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      children: [
        const SizedBox(height: 4),
        _hojaDocumento(reporte),
        const SizedBox(height: 16),
        if (dAnimal != null) ..._detalleAnimal(dAnimal),
        if (dGranja != null) ..._detalleGranja(dGranja),
      ],
    );
  }
}

class _VisorPdfScreen extends StatelessWidget {
  const _VisorPdfScreen({required this.reporte});
  final ReporteGenerado reporte;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: colorFondo,
        appBar: AppBar(
          backgroundColor: colorVerde,
          foregroundColor: Colors.white,
          title: Text(reporte.titulo),
        ),
        body: PdfPreview(
          build: (_) async => reporte.pdf,
          canChangePageFormat: false,
          canChangeOrientation: false,
          canDebug: false,
          pdfFileName: reporte.nombreArchivo,
        ),
      );
}
