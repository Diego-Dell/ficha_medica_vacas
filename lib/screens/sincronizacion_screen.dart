import 'package:flutter/material.dart';

import '../logic/sincronizacion.dart';
import '../widgets/vetlink.dart';

// 1. RF-07: registros guardados en el celular y su estado de envío.
class SincronizacionScreen extends StatefulWidget {
  const SincronizacionScreen({super.key});

  @override
  State<SincronizacionScreen> createState() => _SincronizacionScreenState();
}

class _SincronizacionScreenState extends State<SincronizacionScreen> {
  late Future<List<Pendiente>> _registros = Sincronizacion.instance.registros();
  bool _sincronizando = false;

  @override
  void initState() {
    super.initState();
    Sincronizacion.instance.cambios.addListener(_recargar);
  }

  @override
  void dispose() {
    Sincronizacion.instance.cambios.removeListener(_recargar);
    super.dispose();
  }

  void _recargar() {
    if (mounted) setState(() => _registros = Sincronizacion.instance.registros());
  }

  // 2. Reintento manual; el automático ocurre al volver la conexión.
  Future<void> _sincronizar() async {
    setState(() => _sincronizando = true);
    await Sincronizacion.instance.sincronizar();
    if (!mounted) return;
    setState(() => _sincronizando = false);
    final faltan = await Sincronizacion.instance.porEnviar();
    if (mounted) avisar(context, faltan == 0 ? 'Todo está sincronizado' : 'Quedan $faltan pendientes. Se enviarán al recuperar conexión');
  }

  Future<void> _descartar(Pendiente pendiente) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => VentanaVetLink(
        icono: 'eliminar',
        peligro: true,
        titulo: 'Descartar registro',
        texto: 'El servidor rechazó este registro. Si lo descartás se borra del celular.',
        acciones: [
          BotonPrincipal(texto: 'Descartar', alPresionar: () => Navigator.pop(context, true)),
          BotonSecundario(texto: 'Cancelar', alPresionar: () => Navigator.pop(context, false)),
        ],
      ),
    );
    if (confirmar == true) await Sincronizacion.instance.descartar(pendiente);
  }

  @override
  Widget build(BuildContext context) => PantallaVetLink(
        titulo: 'Sincronización',
        subtitulo: 'Registros guardados en este celular.',
        encabezado: EncabezadoVetLink(alVolver: () => Navigator.pop(context)),
        children: [
          FutureBuilder<List<Pendiente>>(
            future: _registros,
            builder: (context, foto) {
              if (!foto.hasData) return const Center(child: CircularProgressIndicator());
              final registros = foto.data!;
              final faltan = registros.where((r) => r.porEnviar).length;
              final ultima = Sincronizacion.instance.ultimaSincronizacion;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AvisoVetLink(
                    advertencia: faltan > 0,
                    titulo: faltan == 0 ? 'Todo está sincronizado' : '$faltan ${faltan == 1 ? 'registro pendiente' : 'registros pendientes'}',
                    texto: faltan == 0 && ultima == null
                        ? null
                        : [
                            if (faltan > 0) 'Se envían solos al recuperar conexión con la app abierta.',
                            if (ultima != null) 'Último intento: ${_hora(ultima)}.',
                          ].join(' '),
                  ),
                  BotonPrincipal(
                    texto: _sincronizando ? 'Sincronizando...' : 'Sincronizar ahora',
                    alPresionar: _sincronizando ? null : _sincronizar,
                  ),
                  const SizedBox(height: 16),
                  if (registros.isEmpty)
                    const Text('No hay registros guardados en este celular.', textAlign: TextAlign.center)
                  else
                    for (final registro in registros) _Registro(registro, alDescartar: () => _descartar(registro)),
                ],
              );
            },
          ),
        ],
      );
}

String _hora(DateTime fecha) =>
    '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')} '
    '${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';

// 3. Tarjeta de un registro con su estado.
class _Registro extends StatelessWidget {
  const _Registro(this.registro, {required this.alDescartar});

  final Pendiente registro;
  final VoidCallback alDescartar;

  @override
  Widget build(BuildContext context) {
    final tipo = switch (registro.estado) {
      EstadoRegistro.sincronizado => TipoChip.exito,
      EstadoRegistro.guardadoEnDispositivo => TipoChip.neutro,
      EstadoRegistro.pendiente => TipoChip.advertencia,
      EstadoRegistro.rechazado => TipoChip.error,
    };
    final tema = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Tarjeta(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(registro.descripcion, style: tema.titleSmall)),
                ChipEstado(registro.estado.etiqueta, tipo: tipo),
              ],
            ),
            const SizedBox(height: 4),
            Text('Guardado ${_hora(registro.creadoEn)}', style: tema.bodySmall),
            if (registro.error != null) ...[
              const SizedBox(height: 6),
              Text(registro.error!, style: tema.bodySmall?.copyWith(color: colorRojo)),
            ],
            if (registro.estado == EstadoRegistro.rechazado)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(onPressed: alDescartar, child: const Text('Descartar')),
              ),
          ],
        ),
      ),
    );
  }
}
