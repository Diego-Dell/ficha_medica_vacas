import 'package:flutter/material.dart';

import '../../logic/granjas.dart';
import '../../models/miembro.dart';
import '../../widgets/vetlink.dart';
import 'invitar_screen.dart';
import 'expulsar_miembro_screen.dart';

typedef _Equipo = ({List<Miembro> miembros, List<Invitacion> invitaciones});

class MiembrosScreen extends StatefulWidget {
  const MiembrosScreen({super.key});

  @override
  State<MiembrosScreen> createState() => _MiembrosScreenState();
}

class _MiembrosScreenState extends State<MiembrosScreen> {
  late Future<_Equipo> _equipo = _cargar();
  bool _reenviando = false;

  /// 1. Pide a Supabase los miembros y las invitaciones pendientes.
  Future<_Equipo> _cargar() async {
    final datos = Granjas.instance;
    final (miembros, invitaciones) = await (datos.miembros(), datos.invitaciones()).wait;
    return (miembros: miembros, invitaciones: invitaciones);
  }

  /// 2. Vuelve a pedir los datos.
  void _recargar() {
    setState(() {
      _equipo = _cargar();
    });
  }

  /// 3. Reenvía el correo de todas las invitaciones pendientes.
  Future<void> _reenviar() async {
    if (_reenviando) return;
    setState(() => _reenviando = true);
    final List<Invitacion> pendientes;
    try {
      pendientes = (await _equipo).invitaciones;
    } on Object {
      if (mounted) {
        setState(() => _reenviando = false);
        avisar(context, 'No se pudo cargar el equipo. Intenta de nuevo');
      }
      return;
    }
    final resultados = await Future.wait(pendientes.map((i) => Granjas.instance.enviarCorreo(i.id)));
    if (!mounted) return;
    setState(() => _reenviando = false);
    final enviados = resultados.where((error) => error == null).length;
    final motivo = resultados.nonNulls.firstOrNull;
    avisar(
      context,
      pendientes.isEmpty
          ? 'No hay invitaciones pendientes'
          : enviados == pendientes.length
          ? 'Se reenviaron $enviados de $enviados invitaciones'
          : 'Solo se reenviaron $enviados de ${pendientes.length} invitaciones: $motivo',
    );
  }

  @override
  Widget build(BuildContext context) {
    final granja = Granjas.instance.actual.nombre;
    final tema = Theme.of(context).textTheme;
    void volver() => Navigator.pop(context);

    return PantallaVetLink(
      encabezado: EncabezadoVetLink(granja: granja, alVolver: volver),
      titulo: 'Miembros',
      subtitulo: 'Equipo vinculado a $granja.',
      children: [
        FutureBuilder<_Equipo>(
          future: _equipo,
          builder: (context, estado) {
            if (estado.hasError) {
              return TextButton(
                style: TextButton.styleFrom(foregroundColor: colorRojo),
                onPressed: _recargar,
                child: const Text('No se pudo cargar el equipo. Reintentar'),
              );
            }
            final equipo = estado.data;
            if (equipo == null) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 4. Tarjeta por persona: iniciales, nombre con rol y correo.
                for (final m in equipo.miembros)
                  _Persona(
                    iniciales: _iniciales(m.nombre),
                    titulo: '${m.nombre} · ${m.rol.etiqueta}',
                    detalle: '${m.correo} · Activo',
                  ),
                for (final i in equipo.invitaciones)
                  _Persona(
                    iniciales: _iniciales(i.correo),
                    titulo: 'Invitación pendiente',
                    detalle: '${i.correo} · ${i.rol.etiqueta}\nEnviada el ${fechaCorta(i.enviada)}',
                    pendiente: true,
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 4),
        BotonPrincipal(
          texto: 'Invitar persona',
          alPresionar: () async {
            await Navigator.push(context, MaterialPageRoute(builder: (_) => const InvitarScreen()));
            if (mounted) _recargar();
          },
        ),
        BotonSecundario(
          texto: _reenviando ? 'Reenviando...' : 'Reenviar invitación',
          alPresionar: _reenviando ? null : _reenviar,
        ),
        if (Granjas.instance.rol == RolMiembro.dueno)
          BotonSecundario(
            texto: 'Expulsar de la granja',
            alPresionar: () async {
              try {
                final equipo = await _equipo;
                if (!context.mounted) return;
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ExpulsarMiembroScreen(miembros: equipo.miembros)),
                );
                if (mounted) _recargar();
              } on Exception {
                if (context.mounted) {
                  avisar(context, 'No se pudo cargar el equipo. Intenta de nuevo');
                }
              }
            },
          ),
        const SizedBox(height: 4),
        Text(
          'Cada persona conserva el rol asignado en esta granja.',
          style: tema.bodySmall?.copyWith(color: colorTextoSuave),
        ),
      ],
    );
  }
}

String _iniciales(String texto) =>
    texto.split(RegExp(r'[\s@.]')).where((p) => p.isNotEmpty).take(2).map((p) => p[0].toUpperCase()).join();

// 5. Fila del equipo con avatar de iniciales.
class _Persona extends StatelessWidget {
  const _Persona({required this.iniciales, required this.titulo, required this.detalle, this.pendiente = false});

  final String iniciales, titulo, detalle;
  final bool pendiente;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Tarjeta(
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: pendiente ? colorAmbarFondo : colorVerdeSuave,
            child: Text(
              iniciales,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: pendiente ? colorAmbarTexto : colorVerde,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 15)),
                Text(detalle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          if (pendiente) const ChipEstado('Pendiente', tipo: TipoChip.advertencia),
        ],
      ),
    ),
  );
}
