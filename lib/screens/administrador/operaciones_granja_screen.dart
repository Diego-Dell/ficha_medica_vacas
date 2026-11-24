import 'package:flutter/material.dart';

import '../../logic/administracion.dart';
import '../../logic/granjas.dart';
import '../../models/granja.dart';
import '../../widgets/panel_rol.dart';
import '../../widgets/pantalla.dart';
import '../../widgets/vetlink.dart';
import '../dueno_granja/datos_granja_screen.dart';
import '../ganado/ganado_screen.dart';
import '../veterinario/registro_clinico_screen.dart';
import '../veterinario/tratamiento_screen.dart';
import '../veterinario/prevencion_screen.dart';
import '../trabajador/registro_cuidados_screen.dart';
import 'cuenta_administrativa_screen.dart';

class OperacionesGranjaScreen extends StatefulWidget {
  const OperacionesGranjaScreen({super.key, required this.granja});
  final Granja granja;
  @override
  State<OperacionesGranjaScreen> createState() =>
      _OperacionesGranjaScreenState();
}

class _OperacionesGranjaScreenState extends State<OperacionesGranjaScreen> {
  late final Future<bool> _acceso = _autorizar();
  Future<bool> _autorizar() async {
    if (!await Granjas.instance.esAdministrador()) return false;
    Granjas.instance.seleccionarAdministracion(widget.granja);
    return true;
  }

  Future<void> _abrir(Widget pantalla) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => pantalla));
  }

  @override
  Widget build(BuildContext context) => Pantalla(
    titulo: widget.granja.nombre,
    subtitulo: 'Operaciones como administrador',
    children: [
      FutureBuilder(
        future: _acceso,
        builder: (context, estado) {
          if (estado.hasError || estado.data == false) {
            return const AvisoVetLink(
              titulo: 'Acceso no disponible',
              texto: 'Se necesita una cuenta administradora activa y una granja confirmada.',
              advertencia: true,
            );
          }
          if (!estado.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AvisoVetLink(
                titulo: 'Acceso de administrador',
                texto: 'Podés gestionar los módulos de esta granja. Tus intervenciones quedan registradas a tu nombre.',
              ),
              Accesos(
                children: [
                  Acceso(
                    titulo: 'Ganado',
                    icono: 'ganado',
                    alPresionar: () => _abrir(const GanadoScreen()),
                  ),
                  Acceso(
                    titulo: 'Miembros',
                    icono: 'miembros',
                    alPresionar: () => _abrir(
                      MiembrosAdministrativosScreen(granja: widget.granja),
                    ),
                  ),
                  Acceso(
                    titulo: 'Datos de granja',
                    icono: 'granja',
                    alPresionar: () => _abrir(const DatosGranjaScreen()),
                  ),
                  Acceso(
                    titulo: 'Clínica',
                    icono: 'clinica',
                    alPresionar: () => _abrir(const RegistroClinicoScreen()),
                  ),
                  Acceso(
                    titulo: 'Reproducción',
                    icono: 'reproduccion',
                    alPresionar: () =>
                        _abrir(const RegistroClinicoScreen(reproductivo: true)),
                  ),
                  Acceso(
                    titulo: 'Tratamientos',
                    icono: 'tratamiento',
                    alPresionar: () => _abrir(const TratamientoScreen()),
                  ),
                  Acceso(
                    titulo: 'Prevención',
                    icono: 'vacuna',
                    alPresionar: () => _abrir(const PrevencionScreen()),
                  ),
                  Acceso(
                    titulo: 'Observaciones',
                    icono: 'cuidado',
                    alPresionar: () => _abrir(const ObservacionScreen()),
                  ),
                  Acceso(
                    titulo: 'Aplicaciones',
                    icono: 'medicamento',
                    alPresionar: () => _abrir(const AplicacionScreen()),
                  ),
                  Acceso(
                    titulo: 'Historial',
                    icono: 'ficha',
                    alPresionar: () => _abrir(const GanadoScreen()),
                  ),
                  const Acceso(
                    titulo: 'Avisos',
                    icono: 'avisos',
                    alPresionar: null,
                  ),
                  const Acceso(
                    titulo: 'Reportes',
                    icono: 'reportes',
                    alPresionar: null,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Avisos y reportes se habilitarán al integrar RF-06 y RF-08 del equipo.',
                style: TextStyle(color: colorTextoSuave, fontSize: 12),
              ),
            ],
          );
        },
      ),
    ],
  );
}

class MiembrosAdministrativosScreen extends StatefulWidget {
  const MiembrosAdministrativosScreen({super.key, required this.granja});
  final Granja granja;
  @override
  State<MiembrosAdministrativosScreen> createState() =>
      _MiembrosAdministrativosScreenState();
}

class _MiembrosAdministrativosScreenState
    extends State<MiembrosAdministrativosScreen> {
  late Future<List<Map<String, dynamic>>> _datos = Administracion.instance
      .miembros(widget.granja.id);
  bool _guardando = false;
  @override
  Widget build(BuildContext context) => Pantalla(
    titulo: 'Miembros',
    granja: widget.granja.nombre,
    children: [
      FutureBuilder(
        future: _datos,
        builder: (context, estado) {
          if (estado.hasError) {
            return TextButton(
              onPressed: () => setState(
                () =>
                    _datos = Administracion.instance.miembros(widget.granja.id),
              ),
              child: const Text('No se pudieron cargar. Reintentar'),
            );
          }
          if (!estado.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return Column(
            children: [
              if (estado.data!.isEmpty) const Text('No hay miembros.'),
              for (final miembro in estado.data!)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Tarjeta(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '${miembro['nombre']}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text('${miembro['correo']}'),
                        Text(
                          '${miembro['rol']} · ${miembro['activa'] == true ? 'Activo' : 'Suspendido'}',
                        ),
                        TextButton(
                          onPressed: _guardando
                              ? null
                              : () async {
                                  if (!await confirmarAdministracion(
                                    context,
                                    'Cambiar acceso',
                                    '¿Cambiar el acceso de ${miembro['nombre']} a esta granja? Sus registros se conservarán.',
                                  )) {
                                    return;
                                  }
                                  if (!mounted) return;
                                  setState(() => _guardando = true);
                                  try {
                                    await Administracion.instance.cambiarAcceso(
                                      miembro['id'] as String,
                                      miembro['activa'] != true,
                                    );
                                    if (mounted) {
                                      setState(
                                        () { _datos = Administracion.instance.miembros(widget.granja.id); },
                                      );
                                    }
                                  } on Exception catch (e) {
                                    if (context.mounted) {
                                      avisar(
                                        context,
                                        e.toString().replaceFirst(
                                          'Exception: ',
                                          '',
                                        ),
                                      );
                                    }
                                  } finally {
                                    if (mounted) {
                                      setState(() => _guardando = false);
                                    }
                                  }
                                },
                          child: Text(
                            miembro['activa'] == true
                                ? 'Desactivar acceso'
                                : 'Restablecer acceso',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    ],
  );
}
