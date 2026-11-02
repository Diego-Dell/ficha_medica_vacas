import 'package:flutter/material.dart';

import '../logic/granjas.dart';
import '../logic/sesion.dart';
import '../widgets/vetlink.dart';
import 'dar_de_baja_screen.dart';
import 'miembros_screen.dart';
import 'registrar_otra_granja_screen.dart';

class MiGranjaScreen extends StatefulWidget {
  const MiGranjaScreen({super.key});

  @override
  State<MiGranjaScreen> createState() => _MiGranjaScreenState();
}

class _MiGranjaScreenState extends State<MiGranjaScreen> {
  void _pronto(String funcion) => avisar(context, '$funcion estará disponible pronto');

  /// Abre una pantalla y actualiza los datos al volver.
  Future<void> _abrir(Widget pantalla) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => pantalla));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final datos = Granjas.instance;
    return PantallaVetLink(
      encabezado: EncabezadoVetLink(
        granja: datos.actual.nombre,
        rol: 'Dueño',
        alVolver: () => Navigator.pop(context),
      ),
      barraInferior: const BarraVetLink(),
      titulo: 'Mi granja',
      subtitulo: '${Sesion.instance.nombre} · Así va el cuidado en ${datos.actual.nombre}.',
      children: [
        const SizedBox(height: 4),
        Row(
          children: [
            _Dato(valor: datos.animales, etiqueta: 'Animales'),
            const SizedBox(width: 8),
            _Dato(valor: datos.avisos, etiqueta: 'Avisos'),
            const SizedBox(width: 8),
            _Dato(valor: datos.totalMiembros, etiqueta: 'Miembros'),
          ],
        ),
        const SizedBox(height: 12),
        _Opcion(
          titulo: 'Ganado e historial',
          detalle: 'Consultar animales y sus antecedentes.',
          alPresionar: () => _pronto('Ganado e historial'),
        ),
        _Opcion(
          titulo: 'Registrar o editar ficha',
          detalle: 'Datos generales de terneras, vaquillas y vacas.',
          alPresionar: () => _pronto('Registrar o editar ficha'),
        ),
        _Opcion(
          titulo: 'Miembros del equipo',
          detalle: 'Invitar personas y comprobar su incorporación.',
          alPresionar: () => _abrir(const MiembrosScreen()),
        ),
        _Opcion(
          titulo: 'Reportes sanitarios',
          detalle: 'Historial por animal y resumen de la granja.',
          alPresionar: () => _pronto('Reportes sanitarios'),
        ),
        _Opcion(
          titulo: 'Dar de baja un animal',
          detalle: 'Conserva la ficha y los antecedentes.',
          alPresionar: () => _abrir(const DarDeBajaScreen()),
        ),
        BotonSecundario(texto: 'Registrar otra granja', alPresionar: () => _abrir(const RegistrarOtraGranjaScreen())),
      ],
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato({required this.valor, required this.etiqueta});

  final int valor;
  final String etiqueta;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: colorBorde),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$valor', style: tema.headlineSmall?.copyWith(color: colorVerdeOscuro, fontWeight: FontWeight.w700)),
            Text(etiqueta, style: tema.labelSmall?.copyWith(color: colorTextoSuave)),
          ],
        ),
      ),
    );
  }
}

class _Opcion extends StatelessWidget {
  const _Opcion({required this.titulo, required this.detalle, required this.alPresionar});

  final String titulo;
  final String detalle;
  final VoidCallback alPresionar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: colorBorde),
          borderRadius: BorderRadius.circular(10),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: alPresionar,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$titulo  ›',
                  style: tema.titleSmall?.copyWith(color: colorVerdeOscuro, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(detalle, style: tema.bodySmall?.copyWith(color: colorTextoSuave)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
