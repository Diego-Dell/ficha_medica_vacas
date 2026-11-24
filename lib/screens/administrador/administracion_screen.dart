import 'package:flutter/material.dart';

import '../../logic/administracion.dart';
import '../../logic/sesion.dart';
import '../../models/granja.dart';
import '../../widgets/panel_rol.dart';
import '../../widgets/pantalla.dart';
import '../../widgets/vetlink.dart';
import 'confirmar_granja_screen.dart';
import 'cuenta_administrativa_screen.dart';
import 'operaciones_granja_screen.dart';

/// Inicio, granjas y cuentas comparten la barra administrativa del diseño.
class AdministracionScreen extends StatefulWidget {
  const AdministracionScreen({super.key, this.alCerrarSesion, this.granja});
  final Granja? granja;
  final VoidCallback? alCerrarSesion;
  @override
  State<AdministracionScreen> createState() => _AdministracionScreenState();
}

class _AdministracionScreenState extends State<AdministracionScreen> {
  int _pestana = 0;
  String _buscar = '';
  final _busqueda = TextEditingController();
  late Future<
    (
      Map<String, dynamic>,
      List<Map<String, dynamic>>,
      List<Map<String, dynamic>>,
    )
  >
  _datos = _cargar();

  Future<
    (
      Map<String, dynamic>,
      List<Map<String, dynamic>>,
      List<Map<String, dynamic>>,
    )
  >
  _cargar() async {
    final api = Administracion.instance;
    return (await api.resumen(), await api.granjas(), await api.cuentas());
  }

  void _recargar() => setState(() { _datos = _cargar(); });
  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  Future<void> _abrirGranja(Map<String, dynamic> fila) async {
    final granja = Granja(
      id: fila['id'] as String,
      nombre: fila['nombre'] as String,
      dueno: fila['dueno'] as String? ?? '',
      superficie: (fila['hectareas'] as num).toDouble(),
      runsa: fila['runsa'] as String? ?? '',
      documento: fila['documentosTerreno'] as String? ?? '',
      confirmada: fila['confirmada'] as bool,
      motivoRechazo: fila['motivoRechazo'] as String?,
    );
    final resultado = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => granja.confirmada
            ? OperacionesGranjaScreen(granja: granja)
            : ConfirmarGranjaScreen(granja: granja),
      ),
    );
    if (!mounted) return;
    if (resultado is bool) {
      avisar(context, resultado ? '${granja.nombre} quedó confirmada' : '${granja.nombre}: solicitud rechazada');
      _pestana = 1;
    }
    _recargar();
  }

  Widget _granja(Map<String, dynamic> fila) => OpcionPanel(
    titulo: fila['nombre'] as String,
    icono: 'granja',
    detalle:
        '${fila['confirmada'] == true ? 'Confirmada' : 'Pendiente'} · ${fila['runsa'] ?? ''}',
    alPresionar: () => _abrirGranja(fila),
  );
  @override
  Widget build(BuildContext context) => Pantalla(
    titulo: [
      'Hola, ${Sesion.instance.nombre.split(RegExp(r'[\s@]')).first}',
      'Granjas',
      'Cuentas y accesos',
    ][_pestana],
    granja: 'Administrador del sistema',
    volver: false,
    barraInferior: NavigationBar(
      backgroundColor: colorSuperficie,
      indicatorColor: colorVerdeSuave,
      selectedIndex: _pestana,
      onDestinationSelected: (i) => setState(() {
        _pestana = i;
        _buscar = '';
        _busqueda.clear();
      }),
      destinations: const [
        NavigationDestination(icon: Icono('inicio'), label: 'Inicio'),
        NavigationDestination(icon: Icono('granja'), label: 'Granjas'),
        NavigationDestination(icon: Icono('miembros'), label: 'Cuentas'),
      ],
    ),
    children: [
      FutureBuilder(
        future: _datos,
        builder: (context, estado) {
          if (estado.hasError) {
            return Column(
              children: [
                const AvisoVetLink(
                  titulo: 'No se pudo cargar la administración',
                  texto: 'Revisá la conexión y los permisos de tu cuenta.',
                  advertencia: true,
                ),
                TextButton(
                  onPressed: _recargar,
                  child: const Text('Reintentar'),
                ),
              ],
            );
          }
          if (!estado.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final (resumen, granjas, cuentas) = estado.data!;
          if (_pestana == 0) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: colorVerde,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Gestión general del sistema',
                        style: TextStyle(color: Colors.white),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          for (final dato in [
                            ('pendientes', 'Por confirmar'),
                            ('granjasActivas', 'Granjas activas'),
                            ('cuentas', 'Cuentas'),
                          ])
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${resumen[dato.$1] ?? 0}',
                                    style: const TextStyle(
                                      fontFamily: fuenteTitulos,
                                      fontSize: 30,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    dato.$2,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const TituloGrupo('Por confirmar'),
                if (!granjas.any((g) => g['confirmada'] == false))
                  const Text('No hay solicitudes pendientes.'),
                for (final g
                    in granjas.where((g) => g['confirmada'] == false).take(2))
                  _granja(g),
                TextButton(
                  onPressed:
                      widget.alCerrarSesion ?? () => cerrarSesion(context),
                  child: const Text('Cerrar sesión'),
                ),
              ],
            );
          }
          final filas = (_pestana == 1 ? granjas : cuentas)
              .where(
                (f) => '${f['nombre']} ${f['correo'] ?? f['runsa'] ?? ''}'
                    .toLowerCase()
                    .contains(_buscar),
              )
              .toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CampoEtiquetado(
                etiqueta: _pestana == 1 ? 'Buscar granja' : 'Buscar cuenta',
                child: TextField(
                  controller: _busqueda,
                  decoration: decoracionCampo(
                    pista: _pestana == 1 ? 'Nombre o RUNSA' : 'Nombre o correo',
                  ),
                  onChanged: (v) =>
                      setState(() => _buscar = v.trim().toLowerCase()),
                ),
              ),
              if (filas.isEmpty) const Text('No hay resultados.'),
              for (final fila in filas)
                if (_pestana == 1)
                  _granja(fila)
                else
                  OpcionPanel(
                    titulo:
                        fila['nombre'] as String? ?? fila['correo'] as String,
                    icono: 'miembros',
                    detalle:
                        '${fila['correo']} · ${fila['activa'] == true ? 'Activa' : 'Desactivada'}',
                    alPresionar: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CuentaAdministrativaScreen(
                            cuentaId: fila['id'] as String,
                          ),
                        ),
                      );
                      if (mounted) _recargar();
                    },
                  ),
            ],
          );
        },
      ),
    ],
  );
}
