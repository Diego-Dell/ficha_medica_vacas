import 'package:flutter/material.dart';

import '../../logic/granjas.dart';
import '../../logic/sesion.dart';
import '../../models/miembro.dart';
import '../../widgets/panel_rol.dart';
import '../../widgets/vetlink.dart';
import 'miembros_screen.dart';
import 'registrar_otra_granja_screen.dart';

class MiGranjaScreen extends StatefulWidget {
  const MiGranjaScreen({super.key});

  @override
  State<MiGranjaScreen> createState() => _MiGranjaScreenState();
}

class _MiGranjaScreenState extends State<MiGranjaScreen> {
  late Future<Resumen> _resumen = Granjas.instance.resumen();

  /// 1. Vuelve a pedir los datos a Supabase.
  void _recargar() {
    setState(() {
      _resumen = Granjas.instance.resumen();
    });
  }

  /// 2. Abre una pantalla y actualiza los datos al volver.
  Future<void> _abrir(Widget pantalla) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => pantalla));
    if (mounted) _recargar();
  }

  @override
  Widget build(BuildContext context) {
    final datos = Granjas.instance;
    final esDueno = datos.rol == RolMiembro.dueno;
    return PanelRol(
      rol: datos.rol.etiqueta,
      granja: datos.actual.nombre,
      subtitulo: '${Sesion.instance.nombre} · Así está el equipo de ${datos.actual.nombre}.',
      children: [
        FutureBuilder<Resumen>(
          future: _resumen,
          builder: (context, estado) {
            final resumen = estado.data;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    _Dato(valor: resumen?.miembros, etiqueta: 'Miembros'),
                    const SizedBox(width: 8),
                    _Dato(valor: resumen?.pendientes, etiqueta: 'Invitaciones pendientes'),
                  ],
                ),
                if (estado.hasError)
                  TextButton(
                    style: TextButton.styleFrom(foregroundColor: colorRojo),
                    onPressed: _recargar,
                    child: const Text('No se pudieron cargar los datos. Reintentar'),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        if (esDueno)
          OpcionPanel(
            titulo: 'Miembros del equipo',
            detalle: 'Invitar personas y comprobar su incorporación.',
            alPresionar: () => _abrir(const MiembrosScreen()),
          ),
        BotonSecundario(texto: 'Registrar otra granja', alPresionar: () => _abrir(const RegistrarOtraGranjaScreen())),
      ],
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato({required this.valor, required this.etiqueta});

  final int? valor;
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
            Text(
              '${valor ?? '–'}',
              style: tema.headlineSmall?.copyWith(color: colorVerdeOscuro, fontWeight: FontWeight.w700),
            ),
            Text(etiqueta, style: tema.labelSmall?.copyWith(color: colorTextoSuave)),
          ],
        ),
      ),
    );
  }
}
