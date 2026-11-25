import 'package:flutter/material.dart';

import '../../logic/cuidados.dart';
import '../../logic/fichas.dart';
import '../../models/animal.dart';
import '../../widgets/panel_rol.dart';
import '../../widgets/vetlink.dart';
import 'registro_cuidados_screen.dart';

/// Inicio del trabajador: indicaciones pendientes y sus dos registros.
class CuidadosHoyScreen extends StatefulWidget {
  const CuidadosHoyScreen({
    super.key,
    required this.granja,
    this.alCerrarSesion,
  });
  final String granja;
  final VoidCallback? alCerrarSesion;

  @override
  State<CuidadosHoyScreen> createState() => _CuidadosHoyScreenState();
}

class _CuidadosHoyScreenState extends State<CuidadosHoyScreen> {
  late Future<({List<Animal> animales, List<Indicacion> indicaciones})>
  _pendientes = _cargar();

  Future<({List<Animal> animales, List<Indicacion> indicaciones})>
  _cargar() async {
    final animales = await Fichas.instance.activos();
    return (
      animales: animales,
      indicaciones: await Cuidados.instance.indicacionesDeAnimales(animales),
    );
  }

  void _recargar() => setState(() => _pendientes = _cargar());

  Future<void> _abrir(Widget pantalla) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => pantalla));
    if (mounted) {
      _recargar();
    }
  }

  @override
  Widget build(BuildContext context) => PanelRol(
    rol: 'Trabajador',
    granja: widget.granja,
    alCerrarSesion: widget.alCerrarSesion,
    children: [
      const TituloGrupo('Gestión de cuidados diarios'),
      FutureBuilder<({List<Animal> animales, List<Indicacion> indicaciones})>(
        future: _pendientes,
        builder: (context, estado) {
          if (estado.hasError) {
            return TextButton(
              onPressed: _recargar,
              child: const Text(
                'No se pudieron cargar las indicaciones. Reintentar',
              ),
            );
          }
          if (!estado.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final datos = estado.data!;
          if (datos.indicaciones.isEmpty) {
            return const AvisoVetLink(
              titulo: 'No hay indicaciones pendientes.',
              texto: 'Podés registrar una observación cuando detectes algo en el ganado.',
            );
          }
          return Column(
            children: [
              for (final indicacion in datos.indicaciones.take(5))
                OpcionPanel(
                  titulo: indicacion.nombre,
                  detalle:
                      '${datos.animales.firstWhere((a) => a.id == indicacion.animalId).titulo} · ${indicacion.tipo}',
                  icono: indicacion.esTratamiento ? 'medicamento' : 'vacuna',
                  alPresionar: () => _abrir(
                    AplicacionScreen(
                      animal: datos.animales.firstWhere(
                        (a) => a.id == indicacion.animalId,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      const TituloGrupo('Registrar'),
      Accesos(
        children: [
          Acceso(
            titulo: 'Observación',
            icono: 'cuidado',
            alPresionar: () => _abrir(const ObservacionScreen()),
          ),
          Acceso(
            titulo: 'Aplicación',
            icono: 'medicamento',
            alPresionar: () => _abrir(const AplicacionScreen()),
          ),
        ],
      ),
    ],
  );
}
