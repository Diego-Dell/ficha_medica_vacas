import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/animal.dart';
import '../models/granja.dart';
import '../models/miembro.dart';
import '../models/prevencion.dart';
import '../models/registro_clinico.dart';
import '../models/tratamiento.dart';
import 'clinica.dart';
import 'consulta_ganado.dart';
import 'cuidados.dart';
import 'fichas.dart';
import 'granjas.dart';
import 'tratamientos.dart';

/// 1. Tipos y periodos de reporte disponibles en RF-08.
enum TipoReporte {
  historialAnimal('Historial sanitario por animal'),
  resumenGranja('Resumen sanitario de la granja');

  const TipoReporte(this.etiqueta);
  final String etiqueta;
}

/// Periodo seleccionable en Generar reportes (Semana, Mes, Año).
enum PeriodoReporte {
  semana('Semana', 'Bajas de la semana'),
  mes('Mes', 'Bajas del mes'),
  anio('Año', 'Bajas del año');

  const PeriodoReporte(this.etiqueta, this.etiquetaBajas);
  final String etiqueta;
  final String etiquetaBajas;

  static const _meses = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];

  /// Rango calendario inclusivo [desde, hasta] del periodo elegido.
  (DateTime, DateTime) rango({DateTime? referencia}) {
    final base = referencia ?? DateTime.now();
    final hoy = DateTime(base.year, base.month, base.day);
    return switch (this) {
      PeriodoReporte.semana => (
        DateTime(hoy.year, hoy.month, hoy.day - 6),
        hoy,
      ),
      PeriodoReporte.mes => (
        DateTime(hoy.year, hoy.month, 1),
        DateTime(hoy.year, hoy.month + 1, 0),
      ),
      PeriodoReporte.anio => (
        DateTime(hoy.year, 1, 1),
        DateTime(hoy.year, 12, 31),
      ),
    };
  }

  /// Subtítulo corto del periodo (por ejemplo "noviembre 2026").
  String subtitulo({DateTime? referencia}) {
    final base = referencia ?? DateTime.now();
    final (desde, hasta) = rango(referencia: base);
    String f(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    return switch (this) {
      PeriodoReporte.semana => '${f(desde)} – ${f(hasta)}',
      PeriodoReporte.mes => '${_meses[base.month - 1]} ${base.year}',
      PeriodoReporte.anio => '${base.year}',
    };
  }
}

/// 2. Datos reunidos para el reporte individual de un animal.
class ReporteAnimalDatos {
  const ReporteAnimalDatos({
    required this.granja,
    required this.animal,
    required this.valoracion,
    required this.atenciones,
    required this.reproductivos,
    required this.tratamientos,
    required this.prevenciones,
    required this.aplicaciones,
    required this.observaciones,
    required this.generadoEn,
    this.advertencias = const [],
  });

  final Granja granja;
  final Animal animal;
  final ValoracionAnimal valoracion;
  final List<RegistroClinico> atenciones;
  final List<RegistroClinico> reproductivos;
  final List<Tratamiento> tratamientos;
  final List<Prevencion> prevenciones;
  final List<AplicacionCuidado> aplicaciones;
  final List<ObservacionCuidado> observaciones;
  final DateTime generadoEn;
  final List<String> advertencias;

  bool get sinRegistrosSanitarios =>
      atenciones.isEmpty &&
      reproductivos.isEmpty &&
      tratamientos.isEmpty &&
      prevenciones.isEmpty &&
      aplicaciones.isEmpty &&
      observaciones.isEmpty;
}

/// 3. Datos reunidos para el resumen sanitario de toda la granja.
class ReporteGranjaDatos {
  const ReporteGranjaDatos({
    required this.granja,
    required this.animales,
    required this.activos,
    required this.bajas,
    required this.valoraciones,
    required this.atenciones,
    required this.reproductivos,
    required this.tratamientos,
    required this.prevenciones,
    required this.avisos,
    required this.generadoEn,
    this.periodo = PeriodoReporte.mes,
    this.advertencias = const [],
  });

  final Granja granja;
  final List<Animal> animales;
  final List<Animal> activos;
  final List<Animal> bajas;
  final Map<String, ValoracionAnimal> valoraciones;
  final List<RegistroClinico> atenciones;
  final List<RegistroClinico> reproductivos;
  final List<Tratamiento> tratamientos;
  final List<Prevencion> prevenciones;
  final List<AvisoGanado> avisos;
  final DateTime generadoEn;
  final PeriodoReporte periodo;
  final List<String> advertencias;

  int get vencidos => avisos.where((a) => a.vencido).length;
  DateTime get desde => periodo.rango(referencia: generadoEn).$1;
  DateTime get hasta => periodo.rango(referencia: generadoEn).$2;
  String get etiquetaPeriodo => periodo.subtitulo(referencia: generadoEn);

  bool _enPeriodo(DateTime fecha) {
    final soloDia = DateTime(fecha.year, fecha.month, fecha.day);
    return !soloDia.isBefore(desde) && !soloDia.isAfter(hasta);
  }

  int get atencionesPeriodo =>
      atenciones.where((r) => !r.anulado && _enPeriodo(r.fecha.toLocal())).length;

  int get tratamientosActivos => tratamientos.where((t) => t.vigente).length;

  int get vacunasAplicadasPeriodo => prevenciones
      .where(
        (p) =>
            !p.pendiente &&
            p.tipo.toLowerCase() == 'vacuna' &&
            _enPeriodo((p.realizada ?? p.fecha).toLocal()),
      )
      .length;

  int get bajasPeriodo => bajas
      .where((a) => a.fechaBaja != null && _enPeriodo(a.fechaBaja!.toLocal()))
      .length;

  ReporteGranjaDatos conPeriodo(PeriodoReporte nuevoPeriodo) => ReporteGranjaDatos(
    granja: granja,
    animales: animales,
    activos: activos,
    bajas: bajas,
    valoraciones: valoraciones,
    atenciones: atenciones,
    reproductivos: reproductivos,
    tratamientos: tratamientos,
    prevenciones: prevenciones,
    avisos: avisos,
    generadoEn: generadoEn,
    periodo: nuevoPeriodo,
    advertencias: advertencias,
  );
}

/// 4. Resultado completo de un reporte: datos estructurados + archivo PDF generado.
class ReporteGenerado {
  const ReporteGenerado({
    required this.tipo,
    required this.titulo,
    required this.nombreArchivo,
    required this.pdf,
    this.datosAnimal,
    this.datosGranja,
  });

  final TipoReporte tipo;
  final String titulo;
  final String nombreArchivo;
  final Uint8List pdf;
  final ReporteAnimalDatos? datosAnimal;
  final ReporteGranjaDatos? datosGranja;
}

/// 5. Genera los reportes sanitarios de RF-08 (Singleton + Facade).
///    Solo dueño, administrador y veterinario pueden generar reportes.
class Reportes {
  Reportes._();
  static final instance = Reportes._();

  Cuidados? _cuidadosPrueba;
  bool _probarSinCuidados = false;

  @visibleForTesting
  void usarCuidados(Cuidados? cuidados, {bool omitir = false}) {
    _cuidadosPrueba = cuidados;
    _probarSinCuidados = omitir;
  }

  /// 6. Roles autorizados: dueño, administrador técnico y veterinario.
  bool get puedeGenerar {
    final rol = Granjas.instance.rol;
    return Granjas.instance.sesionAdministradora ||
        rol == RolMiembro.dueno ||
        rol == RolMiembro.veterinario;
  }

  void _validarPermisoYGranja() {
    if (!puedeGenerar) {
      throw const FalloReporte(
        'Solo el dueño, administrador o veterinario pueden generar reportes sanitarios.',
      );
    }
    if (Granjas.instance.seleccionada == null) {
      throw const FalloReporte('Elegí una granja antes de generar el reporte.');
    }
  }

  // Paleta institucional: verde, blanco y rojo de alerta.
  static final _verde = PdfColor.fromHex('#2F5D46');
  static final _verdeOscuro = PdfColor.fromHex('#24402F');
  static final _verdeSuave = PdfColor.fromHex('#E6EBDF');
  static final _rojo = PdfColor.fromHex('#A2453D');
  static final _rojoFondo = PdfColor.fromHex('#F6E4E1');
  static final _ambarFondo = PdfColor.fromHex('#FCEFD9');
  static final _ambarTexto = PdfColor.fromHex('#9A5B13');
  static const _blanco = PdfColors.white;
  static final _gris = PdfColor.fromHex('#5F6B60');
  static final _borde = PdfColor.fromHex('#DDE1D6');

  static pw.ThemeData? _temaPdf;

  static Future<pw.ThemeData> _cargarTemaPdf() async {
    if (_temaPdf != null) return _temaPdf!;
    try {
      final normal = pw.Font.ttf(await rootBundle.load('assets/fonts/Figtree-Regular.ttf'));
      final negrita = pw.Font.ttf(await rootBundle.load('assets/fonts/Figtree-SemiBold.ttf'));
      return _temaPdf = pw.ThemeData.withFont(base: normal, bold: negrita);
    } on Object {
      return _temaPdf = pw.ThemeData.base();
    }
  }

  static String _fecha(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  static String _archivoSeguro(String base) =>
      '${base.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_').replaceAll(RegExp(r'^_+|_+$'), '')}.pdf';

  static pw.TextStyle _estilo({
    double tam = 10,
    pw.FontWeight peso = pw.FontWeight.normal,
    PdfColor? color,
  }) =>
      pw.TextStyle(fontSize: tam, fontWeight: peso, color: color);

  static pw.Widget _encabezado(String titulo, String subtitulo) => pw.Container(
        padding: const pw.EdgeInsets.all(16),
        decoration: pw.BoxDecoration(
          color: _verde,
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'VetLink · Reporte sanitario',
                    style: _estilo(tam: 10, peso: pw.FontWeight.bold, color: _verdeSuave),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    titulo,
                    style: _estilo(tam: 16, peso: pw.FontWeight.bold, color: _blanco),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(subtitulo, style: _estilo(tam: 10, color: _verdeSuave)),
                ],
              ),
            ),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: pw.BoxDecoration(
                color: _blanco,
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Text(
                'PDF',
                style: _estilo(tam: 9, peso: pw.FontWeight.bold, color: _verde),
              ),
            ),
          ],
        ),
      );

  static pw.Widget _pie(DateTime generadoEn) => pw.Container(
        alignment: pw.Alignment.centerRight,
        padding: const pw.EdgeInsets.only(top: 8),
        decoration: pw.BoxDecoration(
          border: pw.Border(top: pw.BorderSide(color: _borde, width: 0.5)),
        ),
        child: pw.Text(
          'VetLink · Generado el ${_fecha(generadoEn)}',
          style: _estilo(tam: 8, color: _gris),
        ),
      );

  static pw.Widget _fila(String etiqueta, String valor, {PdfColor? colorValor}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: 145,
              child: pw.Text(
                etiqueta,
                style: _estilo(peso: pw.FontWeight.bold, color: _verdeOscuro),
              ),
            ),
            pw.Expanded(
              child: pw.Text(
                valor,
                style: _estilo(color: colorValor ?? _verdeOscuro),
              ),
            ),
          ],
        ),
      );

  static pw.Widget _seccion(String titulo, List<pw.Widget> children, {bool alerta = false}) =>
      pw.Container(
        margin: const pw.EdgeInsets.only(top: 12),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: pw.BoxDecoration(
                color: alerta ? _rojo : _verde,
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Text(
                titulo,
                style: _estilo(tam: 11, peso: pw.FontWeight.bold, color: _blanco),
              ),
            ),
            pw.SizedBox(height: 6),
            ...children,
          ],
        ),
      );

  static pw.Widget _cajaAlerta(String texto, {bool peligro = true}) => pw.Container(
        width: double.infinity,
        margin: const pw.EdgeInsets.only(bottom: 8),
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          color: peligro ? _rojoFondo : _ambarFondo,
          border: pw.Border.all(color: peligro ? _rojo : _ambarTexto, width: 0.6),
          borderRadius: pw.BorderRadius.circular(4),
        ),
        child: pw.Text(
          texto,
          style: _estilo(
            tam: 9,
            peso: pw.FontWeight.bold,
            color: peligro ? _rojo : _ambarTexto,
          ),
        ),
      );

  // ─── HISTORIAL SANITARIO POR ANIMAL ───────────────────────────────

  /// 7. Reúne todos los datos del animal, genera su PDF y devuelve datos + bytes.
  Future<ReporteGenerado> generarHistorialAnimal(Animal animal) async {
    _validarPermisoYGranja();
    final granja = Granjas.instance.actual;
    final advertencias = <String>[];
    var fallos = 0;

    Future<List<T>> intentar<T>(String nombre, Future<List<T>> Function() pedido) async {
      try {
        return await pedido();
      } on FalloClinica catch (e) {
        fallos++;
        advertencias.add('$nombre: ${e.mensaje}');
        return const [];
      } on FalloTratamientos catch (e) {
        fallos++;
        advertencias.add('$nombre: ${e.mensaje}');
        return const [];
      } on Exception {
        fallos++;
        advertencias.add('No se pudo cargar $nombre.');
        return const [];
      }
    }

    final (atenciones, reproductivos, tratamientosList, prevencionesList) = await (
      intentar('atenciones clínicas', () => Clinica.instance.antecedentes(animal.id, reproductivos: false)),
      intentar('eventos reproductivos', () => Clinica.instance.antecedentes(animal.id, reproductivos: true)),
      intentar('tratamientos', () => Tratamientos.instance.delAnimal(animal.id)),
      intentar('prevenciones', () => Tratamientos.instance.prevencionesDelAnimal(animal.id)),
    ).wait;

    if (fallos == 4) {
      throw FalloReporte(
        advertencias.firstOrNull ??
            'No se pudieron cargar los datos sanitarios del animal. Revisá tu conexión e intentá nuevamente.',
      );
    }

    var aplicaciones = <AplicacionCuidado>[];
    var observaciones = <ObservacionCuidado>[];
    if (!_probarSinCuidados) {
      final cuidados = _cuidadosPrueba ?? Cuidados.instance;
      try {
        aplicaciones = await cuidados.aplicacionesDe(animal);
        observaciones = await cuidados.observacionesDe(animal);
      } on Object {
        // Si el módulo de cuidados no está conectado en este entorno, continúa con lo clínico y preventivo.
      }
    }

    final valoracion = valoracionesPorAnimal([animal], reproductivos)[animal.id] ??
        const ValoracionAnimal();
    final generadoEn = DateTime.now();

    final datos = ReporteAnimalDatos(
      granja: granja,
      animal: animal,
      valoracion: valoracion,
      atenciones: atenciones,
      reproductivos: reproductivos,
      tratamientos: tratamientosList,
      prevenciones: prevencionesList,
      aplicaciones: aplicaciones,
      observaciones: observaciones,
      generadoEn: generadoEn,
      advertencias: advertencias,
    );

    if (datos.sinRegistrosSanitarios && advertencias.isEmpty) {
      advertencias.add('Este animal todavía no tiene registros clínicos, tratamientos ni prevenciones.');
    }

    final pdf = await _construirPdfAnimal(datos);
    return ReporteGenerado(
      tipo: TipoReporte.historialAnimal,
      titulo: 'Historial sanitario · ${animal.titulo}',
      nombreArchivo: _archivoSeguro('historial_${animal.arete}_${granja.nombre}'),
      pdf: pdf,
      datosAnimal: datos,
    );
  }

  /// Método directo para obtener únicamente los bytes del PDF individual.
  Future<Uint8List> historialAnimal(Animal animal) async =>
      (await generarHistorialAnimal(animal)).pdf;

  Future<Uint8List> _construirPdfAnimal(ReporteAnimalDatos datos) async {
    final animal = datos.animal;
    final granja = datos.granja;
    final hoy = DateTime(datos.generadoEn.year, datos.generadoEn.month, datos.generadoEn.day);
    final tema = await _cargarTemaPdf();
    final pdf = pw.Document(theme: tema);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        header: (_) => _encabezado(
          'Historial sanitario por animal',
          '${animal.titulo} · ${granja.nombre} (RUNSA ${granja.runsa})',
        ),
        footer: (_) => _pie(datos.generadoEn),
        build: (context) => [
          pw.SizedBox(height: 10),
          if (animal.deBaja)
            _cajaAlerta(
              'Animal dado de baja el ${animal.fechaBaja != null ? _fecha(animal.fechaBaja!) : '-'}: ${animal.motivoBaja ?? 'Sin motivo registrado'}',
            ),
          for (final aviso in datos.advertencias) _cajaAlerta(aviso, peligro: false),
          _seccion('Datos del animal y granja', [
            _fila('Granja', '${granja.nombre} (RUNSA ${granja.runsa})'),
            _fila('Identificación', animal.arete),
            if (animal.nombre != null) _fila('Nombre', animal.nombre!),
            _fila('Etapa', animal.etapa.etiqueta),
            if (animal.raza != null) _fila('Raza', animal.raza!),
            _fila(
              'Nacimiento',
              animal.nacimiento == null
                  ? 'Sin registrar'
                  : '${_fecha(animal.nacimiento!)}${animal.nacimientoEstimado ? ' (estimado)' : ''}',
            ),
            _fila(
              'Estado',
              animal.deBaja ? 'De baja' : 'Activo',
              colorValor: animal.deBaja ? _rojo : _verde,
            ),
            _fila('Aptitud reproductiva', datos.valoracion.aptitudTexto),
            _fila('Estado de preñez', datos.valoracion.prenezTexto),
          ]),
          _seccion('Atenciones clínicas (${datos.atenciones.length})', [
            if (datos.atenciones.isEmpty)
              pw.Text('Sin atenciones clínicas registradas.', style: _estilo(color: _gris)),
            for (final r in datos.atenciones) _registroClinicoPdf(r),
          ]),
          _seccion('Eventos reproductivos (${datos.reproductivos.length})', [
            if (datos.reproductivos.isEmpty)
              pw.Text('Sin eventos reproductivos registrados.', style: _estilo(color: _gris)),
            for (final r in datos.reproductivos) _registroClinicoPdf(r),
          ]),
          _seccion('Tratamientos (${datos.tratamientos.length})', [
            if (datos.tratamientos.isEmpty)
              pw.Text('Sin tratamientos registrados.', style: _estilo(color: _gris)),
            for (final t in datos.tratamientos) _tratamientoPdf(t),
          ]),
          _seccion('Prevención (${datos.prevenciones.length})', [
            if (datos.prevenciones.isEmpty)
              pw.Text('Sin prevenciones registradas.', style: _estilo(color: _gris)),
            for (final p in datos.prevenciones) _prevencionPdf(p, hoy),
          ]),
          if (datos.aplicaciones.isNotEmpty || datos.observaciones.isNotEmpty)
            _seccion(
              'Cuidados y aplicaciones (${datos.aplicaciones.length + datos.observaciones.length})',
              [
                for (final a in datos.aplicaciones)
                  _fila(
                    'Aplicación · ${_fecha(a.fecha.toLocal())}',
                    '${a.dosis} ${a.unidad}${a.observacion?.isNotEmpty == true ? ' · ${a.observacion}' : ''}',
                  ),
                for (final o in datos.observaciones)
                  _fila(
                    'Observación · ${_fecha(o.fecha.toLocal())}',
                    '${o.observado} -> Cuidado: ${o.cuidado}',
                  ),
              ],
            ),
        ],
      ),
    );
    return pdf.save();
  }

  pw.Widget _registroClinicoPdf(RegistroClinico r) => pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 8),
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: r.anulado ? _rojo : _verde, width: 0.6),
          borderRadius: pw.BorderRadius.circular(4),
          color: r.anulado ? _rojoFondo : _blanco,
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  '${_fecha(r.fecha)} · ${r.titulo}',
                  style: _estilo(
                    peso: pw.FontWeight.bold,
                    color: r.anulado ? _rojo : _verdeOscuro,
                  ),
                ),
                if (r.anulado)
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: pw.BoxDecoration(
                      color: _rojo,
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Text('Anulado', style: _estilo(tam: 8, color: _blanco)),
                  ),
              ],
            ),
            if (r.detalle.isNotEmpty)
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 2),
                child: pw.Text(r.detalle, style: _estilo(color: _verdeOscuro)),
              ),
            if (r.reproductivo) ...[
              pw.Text('Aptitud: ${r.aptitudTexto} · Preñez: ${r.prenezTexto}',
                  style: _estilo(tam: 9, color: _gris)),
              if (r.proximoControl != null)
                pw.Text('Próximo control: ${_fecha(DateTime.parse(r.proximoControl!))}',
                    style: _estilo(tam: 9, color: _gris)),
              if (r.partoProbable != null)
                pw.Text('Parto probable: ${_fecha(DateTime.parse(r.partoProbable!))}',
                    style: _estilo(tam: 9, color: _gris)),
            ],
          ],
        ),
      );

  pw.Widget _tratamientoPdf(Tratamiento t) => pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 8),
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: t.anulado ? _rojo : _verde, width: 0.6),
          borderRadius: pw.BorderRadius.circular(4),
          color: t.anulado ? _rojoFondo : _blanco,
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  t.medicamento,
                  style: _estilo(peso: pw.FontWeight.bold, color: _verdeOscuro),
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: pw.BoxDecoration(
                    color: t.vigente ? _verde : (t.anulado ? _rojo : _gris),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Text(t.estado, style: _estilo(tam: 8, color: _blanco)),
                ),
              ],
            ),
            pw.Text('Dosis: ${t.dosis} ${t.unidad} · Vía: ${t.via}',
                style: _estilo(color: _verdeOscuro)),
            pw.Text('Frecuencia: ${t.frecuencia} · Duración: ${t.duracion}',
                style: _estilo(color: _verdeOscuro)),
            pw.Text('Inicio: ${_fecha(t.inicio)}', style: _estilo(tam: 9, color: _gris)),
            if (t.fechaFin != null)
              pw.Text('Cierre: ${_fecha(t.fechaFin!)} · ${t.motivoFin ?? ''}',
                  style: _estilo(tam: 9, color: _gris)),
            if (t.retiro?.isNotEmpty == true)
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 2),
                child: pw.Text(
                  'Retiro: ${t.retiro}',
                  style: _estilo(tam: 9, peso: pw.FontWeight.bold, color: _rojo),
                ),
              ),
          ],
        ),
      );

  pw.Widget _prevencionPdf(Prevencion p, DateTime hoy) {
    final fechaDia = DateTime(p.fecha.year, p.fecha.month, p.fecha.day);
    final vencida = p.pendiente && fechaDia.isBefore(hoy);
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 8),
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: vencida ? _rojo : _verde, width: 0.6),
        borderRadius: pw.BorderRadius.circular(4),
        color: vencida ? _rojoFondo : _blanco,
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                '${p.tipoTexto} · ${p.nombre}',
                style: _estilo(peso: pw.FontWeight.bold, color: _verdeOscuro),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: pw.BoxDecoration(
                  color: vencida
                      ? _rojo
                      : (p.pendiente ? _ambarTexto : _verde),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text(
                  vencida ? 'Vencido' : p.estadoTexto,
                  style: _estilo(tam: 8, color: _blanco),
                ),
              ),
            ],
          ),
          pw.Text('Programada: ${_fecha(p.fecha)}', style: _estilo(tam: 9, color: _gris)),
          if (p.realizada != null)
            pw.Text('Realizada: ${_fecha(p.realizada!)}', style: _estilo(tam: 9, color: _gris)),
        ],
      ),
    );
  }

  // ─── RESUMEN SANITARIO DE LA GRANJA ───────────────────────────────

  Future<ReporteGranjaDatos?> _recolectarDatosGranja({
    required PeriodoReporte periodo,
    required bool exigirAnimales,
  }) async {
    _validarPermisoYGranja();
    final granja = Granjas.instance.actual;

    final List<Animal> animales;
    try {
      animales = await Fichas.instance.deLaGranja(conBajas: true);
    } on Exception {
      throw const FalloReporte(
        'No se pudieron cargar las fichas del ganado. Revisá tu conexión e intentá nuevamente.',
      );
    }

    if (animales.isEmpty) {
      if (exigirAnimales) {
        throw FalloReporte(
          'La granja ${granja.nombre} no tiene animales registrados para generar el resumen.',
        );
      }
      return ReporteGranjaDatos(
        granja: granja,
        animales: const [],
        activos: const [],
        bajas: const [],
        valoraciones: const {},
        atenciones: const [],
        reproductivos: const [],
        tratamientos: const [],
        prevenciones: const [],
        avisos: const [],
        generadoEn: DateTime.now(),
        periodo: periodo,
        advertencias: const ['Registrá al menos un animal en la granja para generar reportes.'],
      );
    }

    final activos = animales.where((a) => !a.deBaja).toList();
    final bajas = animales.where((a) => a.deBaja).toList();
    final advertencias = <String>[];
    var fallosClinica = 0;
    var fallosPrevencion = 0;

    List<RegistroClinico> reproductivos = const [];
    try {
      reproductivos = await Clinica.instance.valoracionesDeAnimales(animales);
    } on Exception {
      fallosClinica++;
      advertencias.add('No se pudieron cargar las valoraciones reproductivas.');
    }

    List<Prevencion> prevenciones = const [];
    try {
      prevenciones = await Tratamientos.instance.prevencionesDeAnimales(animales);
    } on Exception {
      fallosPrevencion++;
      advertencias.add('No se pudieron cargar las prevenciones de la granja.');
    }

    final todasAtenciones = <RegistroClinico>[];
    final todosTratamientos = <Tratamiento>[];
    var animalesFallidos = 0;

    await Future.wait([
      for (final animal in animales)
        () async {
          var falloEste = false;
          try {
            todasAtenciones.addAll(
              await Clinica.instance.antecedentes(animal.id, reproductivos: false),
            );
          } on Exception {
            falloEste = true;
          }
          try {
            todosTratamientos.addAll(
              await Tratamientos.instance.delAnimal(animal.id),
            );
          } on Exception {
            falloEste = true;
          }
          if (falloEste) animalesFallidos++;
        }(),
    ]);

    if (animalesFallidos == animales.length && fallosClinica > 0 && fallosPrevencion > 0) {
      throw const FalloReporte(
        'No se pudo obtener la información sanitaria de la granja. Revisá tu conexión e intentá nuevamente.',
      );
    }
    if (animalesFallidos > 0) {
      advertencias.add(
        'No se pudo completar el detalle clínico/tratamientos de $animalesFallidos de ${animales.length} animales.',
      );
    }

    final valoraciones = valoracionesPorAnimal(animales, reproductivos);
    final generadoEn = DateTime.now();
    final avisos = avisosDeGranja(animales, prevenciones, hoy: generadoEn);

    return ReporteGranjaDatos(
      granja: granja,
      animales: animales,
      activos: activos,
      bajas: bajas,
      valoraciones: valoraciones,
      atenciones: todasAtenciones,
      reproductivos: reproductivos,
      tratamientos: todosTratamientos,
      prevenciones: prevenciones,
      avisos: avisos,
      generadoEn: generadoEn,
      periodo: periodo,
      advertencias: advertencias,
    );
  }

  /// Carga las cifras reales y animales de la granja para la pantalla Generar reportes.
  Future<ReporteGranjaDatos> cargarVistaGranja({
    PeriodoReporte periodo = PeriodoReporte.mes,
  }) async =>
      (await _recolectarDatosGranja(periodo: periodo, exigirAnimales: false))!;

  /// 8. Reúne los datos sanitarios de la granja, genera el PDF y devuelve datos + bytes.
  Future<ReporteGenerado> generarResumenGranja({
    PeriodoReporte periodo = PeriodoReporte.mes,
    ReporteGranjaDatos? datosPrevios,
  }) async {
    _validarPermisoYGranja();
    final ReporteGranjaDatos datos;
    if (datosPrevios != null && datosPrevios.animales.isNotEmpty) {
      datos = datosPrevios.conPeriodo(periodo);
    } else {
      datos = (await _recolectarDatosGranja(periodo: periodo, exigirAnimales: true))!;
    }

    final pdf = await _construirPdfGranja(datos);
    return ReporteGenerado(
      tipo: TipoReporte.resumenGranja,
      titulo: 'Resumen sanitario · ${datos.granja.nombre}',
      nombreArchivo: _archivoSeguro('resumen_${datos.granja.nombre}'),
      pdf: pdf,
      datosGranja: datos,
    );
  }

  /// Método directo para obtener únicamente los bytes del PDF de la granja.
  Future<Uint8List> resumenGranja({PeriodoReporte periodo = PeriodoReporte.mes}) async =>
      (await generarResumenGranja(periodo: periodo)).pdf;

  Future<Uint8List> _construirPdfGranja(ReporteGranjaDatos datos) async {
    final granja = datos.granja;
    final vencidos = datos.vencidos;
    final atencionesVigentes = datos.atencionesPeriodo;
    final reproVigentes = datos.reproductivos.where((r) => !r.anulado).length;
    final tratVigentes = datos.tratamientosActivos;
    final tratFin = datos.tratamientos.where((t) => !t.vigente && !t.anulado).length;
    final prevPendientes = datos.prevenciones.where((p) => p.pendiente).length;
    final vacunasAplicadas = datos.vacunasAplicadasPeriodo;

    final tema = await _cargarTemaPdf();
    final pdf = pw.Document(theme: tema);
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        header: (_) => _encabezado(
          'Resumen sanitario de la granja',
          '${granja.nombre} · ${datos.etiquetaPeriodo} · RUNSA ${granja.runsa}',
        ),
        footer: (_) => _pie(datos.generadoEn),
        build: (context) => [
          pw.SizedBox(height: 10),
          if (vencidos > 0)
            _cajaAlerta('Alerta sanitaria: hay $vencidos avisos preventivos vencidos en la granja.'),
          for (final aviso in datos.advertencias) _cajaAlerta(aviso, peligro: false),
          _seccion('Datos de la granja', [
            _fila('Nombre', granja.nombre),
            _fila('RUNSA', granja.runsa),
            _fila('Superficie', '${granja.superficie} hectáreas'),
            _fila('Periodo', '${datos.periodo.etiqueta} (${_fecha(datos.desde)} – ${_fecha(datos.hasta)})'),
          ]),
          _seccion('Resumen del ganado', [
            _fila('Total de animales', '${datos.animales.length}'),
            _fila('Activos', '${datos.activos.length}', colorValor: _verde),
            _fila(
              datos.periodo.etiquetaBajas,
              '${datos.bajasPeriodo}',
              colorValor: datos.bajasPeriodo > 0 ? _rojo : _verdeOscuro,
            ),
            for (final etapa in Etapa.values)
              _fila(
                '  ${etapa.etiqueta}',
                '${datos.activos.where((a) => a.etapa == etapa).length}',
              ),
          ]),
          _seccion('Resumen clínico y tratamientos', [
            _fila('Atenciones clínicas (${datos.periodo.etiqueta})', '$atencionesVigentes'),
            _fila('Eventos reproductivos vigentes', '$reproVigentes'),
            _fila('Tratamientos activos', '$tratVigentes'),
            _fila('Tratamientos finalizados', '$tratFin'),
          ]),
          _seccion('Resumen preventivo', [
            _fila('Vacunas aplicadas (${datos.periodo.etiqueta})', '$vacunasAplicadas'),
            _fila('Prevenciones pendientes', '$prevPendientes'),
            _fila(
              'Controles vencidos',
              '$vencidos',
              colorValor: vencidos > 0 ? _rojo : _verde,
            ),
          ]),
          if (datos.avisos.isNotEmpty)
            _seccion(
              'Avisos sanitarios (${datos.avisos.length})',
              [
                for (final a in datos.avisos)
                  _fila(
                    '${a.animal.titulo} · ${a.prevencion.tipoTexto}',
                    '${a.prevencion.nombre} (${_fecha(a.prevencion.fecha)}) - ${a.vencido ? 'VENCIDO' : 'Pendiente'}',
                    colorValor: a.vencido ? _rojo : _ambarTexto,
                  ),
              ],
              alerta: vencidos > 0,
            ),
          _seccion('Detalle del ganado (${datos.animales.length})', [
            _tablaAnimales(datos.animales, datos.valoraciones),
          ]),
        ],
      ),
    );
    return pdf.save();
  }

  pw.Widget _tablaAnimales(
    List<Animal> animales,
    Map<String, ValoracionAnimal> valoraciones,
  ) {
    if (animales.isEmpty) return pw.SizedBox.shrink();
    return pw.TableHelper.fromTextArray(
      border: pw.TableBorder.all(color: _verde, width: 0.5),
      headerStyle: _estilo(tam: 9, peso: pw.FontWeight.bold, color: _blanco),
      cellStyle: _estilo(tam: 8.5, color: _verdeOscuro),
      headerDecoration: pw.BoxDecoration(color: _verde),
      cellPadding: const pw.EdgeInsets.all(4),
      headers: ['Arete', 'Nombre', 'Etapa', 'Aptitud', 'Preñez', 'Estado'],
      data: [
        for (final a in animales)
          [
            a.arete,
            a.nombre ?? '-',
            a.etapa.etiqueta,
            valoraciones[a.id]?.aptitudTexto ?? 'Sin evaluar',
            valoraciones[a.id]?.prenezTexto ?? 'No determinada',
            a.deBaja ? 'De baja' : 'Activo',
          ],
      ],
    );
  }
}

/// 9. Error claro cuando faltan datos, permisos o conexión para generar el reporte.
class FalloReporte implements Exception {
  const FalloReporte(this.mensaje);
  final String mensaje;
  @override
  String toString() => mensaje;
}
