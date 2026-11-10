import 'package:flutter/material.dart';

import '../../logic/granjas.dart';
import '../../models/granja.dart';
import '../../widgets/panel_rol.dart';
import '../../widgets/vetlink.dart';
import 'confirmar_granja_screen.dart';

class AdministracionScreen extends StatefulWidget {
  const AdministracionScreen({
    super.key,
    this.alCerrarSesion,
    bool vistaPrevia = false,
    String? granja,
    int? pendientes,
  }) : vistaPrevia = vistaPrevia || pendientes != null;

  final VoidCallback? alCerrarSesion;
  final bool vistaPrevia;

  @override
  State<AdministracionScreen> createState() => _AdministracionScreenState();
}

class _AdministracionScreenState extends State<AdministracionScreen> {
  List<Granja> _pendientes = [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.vistaPrevia) {
      _cargando = false;
    } else {
      _cargarSolicitudes();
    }
  }

  Future<void> _cargarSolicitudes() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final solicitudes = await Granjas.instance.granjasPendientes();
      if (!mounted) return;
      setState(() {
        _pendientes = solicitudes;
        _cargando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudieron cargar las solicitudes.';
        _cargando = false;
      });
    }
  }

  Future<void> _abrirSolicitud(Granja granja) async {
    final confirmada = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ConfirmarGranjaScreen(granja: granja)),
    );
    if (confirmada == true && mounted) {
      avisar(context, 'Granja confirmada. Se envió un correo al dueño.');
      await _cargarSolicitudes();
    }
  }

  @override
  Widget build(BuildContext context) => PanelRol(
    titulo: 'Confirmar granjas',
    subtitulo:
        'Revisa los datos de cada solicitud antes de habilitar el acceso.',
    rol: 'Administrador',
    granja: 'Administración',
    alCerrarSesion: widget.alCerrarSesion,
    children: [
      Container(
        padding: const EdgeInsets.all(13),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: colorVerdeSuave,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Expanded(
              child: Text(
                'Solicitudes recibidas',
                style: TextStyle(
                  color: colorVerdeOscuro,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (!widget.vistaPrevia)
              IconButton(
                tooltip: 'Actualizar solicitudes',
                onPressed: _cargando ? null : _cargarSolicitudes,
                icon: const Icon(Icons.refresh, color: colorVerde),
              ),
          ],
        ),
      ),
      if (_cargando)
        const Padding(
          padding: EdgeInsets.all(28),
          child: Center(child: CircularProgressIndicator()),
        )
      else if (_error != null)
        _EstadoSolicitudes(
          icono: Icons.cloud_off_outlined,
          mensaje: _error!,
          accion: TextButton(
            onPressed: _cargarSolicitudes,
            child: const Text('Intentar de nuevo'),
          ),
        )
      else if (_pendientes.isEmpty)
        _EstadoSolicitudes(
          icono: Icons.inbox_outlined,
          mensaje: widget.vistaPrevia
              ? 'La vista previa no contiene solicitudes. En la aplicación, la lista se carga desde el servidor.'
              : 'No hay solicitudes pendientes de revisión.',
        )
      else ...[
        Text(
          '${_pendientes.length} ${_pendientes.length == 1 ? 'granja pendiente' : 'granjas pendientes'}',
          style: const TextStyle(
            color: colorTextoSuave,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        for (final granja in _pendientes)
          _SolicitudCard(
            granja: granja,
            alPresionar: () => _abrirSolicitud(granja),
          ),
      ],
    ],
  );
}

class _SolicitudCard extends StatelessWidget {
  const _SolicitudCard({required this.granja, required this.alPresionar});

  final Granja granja;
  final VoidCallback alPresionar;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: colorBorde),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: alPresionar,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Icon(Icons.agriculture_outlined, color: colorVerde),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      granja.nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: colorVerdeOscuro,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Dueño: ${granja.dueno}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: colorTextoSuave,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      'RUNSA: ${granja.runsa}',
                      style: const TextStyle(
                        color: colorTextoSuave,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: colorVerde),
            ],
          ),
        ),
      ),
    ),
  );
}

class _EstadoSolicitudes extends StatelessWidget {
  const _EstadoSolicitudes({
    required this.icono,
    required this.mensaje,
    this.accion,
  });

  final IconData icono;
  final String mensaje;
  final Widget? accion;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 8),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: colorBorde),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      children: [
        Icon(icono, color: colorTextoSuave, size: 28),
        const SizedBox(height: 8),
        Text(
          mensaje,
          textAlign: TextAlign.center,
          style: const TextStyle(color: colorTextoSuave, fontSize: 13),
        ),
        if (accion != null) ...[const SizedBox(height: 8), accion!],
      ],
    ),
  );
}
