import 'package:flutter/material.dart';

import '../../logic/granjas.dart';
import '../../models/miembro.dart';
import '../../widgets/vetlink.dart';
import 'invitar_screen.dart';

typedef _Equipo = ({List<Miembro> miembros, List<Invitacion> invitaciones});

class MiembrosScreen extends StatefulWidget {
  const MiembrosScreen({super.key});

  @override
  State<MiembrosScreen> createState() => _MiembrosScreenState();
}

class _MiembrosScreenState extends State<MiembrosScreen> {
  late Future<_Equipo> _equipo = _cargar();
  bool _reenviando = false;

  /// 1. Pide al servidor los miembros y las invitaciones pendientes.
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
    final errores = resultados.whereType<String>().toSet().join('. ');
    avisar(
      context,
      pendientes.isEmpty
          ? 'No hay invitaciones pendientes'
          : enviados == pendientes.length
              ? 'Se reenviaron $enviados de $enviados invitaciones'
              : 'Solo se reenviaron $enviados de ${pendientes.length} invitaciones. $errores. Puedes volver a reenviar',
    );
  }

  @override
  Widget build(BuildContext context) {
    final granja = Granjas.instance.actual.nombre;
    final tema = Theme.of(context).textTheme;
    void volver() => Navigator.pop(context);

    return PantallaVetLink(
      encabezado: EncabezadoVetLink(granja: granja, alVolver: volver),
      barraInferior: BarraVetLink(alVolver: volver),
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
                for (final m in equipo.miembros)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
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
                          '${m.nombre} · ${m.rol.etiqueta}',
                          style: tema.titleSmall?.copyWith(color: colorVerdeOscuro, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text('${m.correo} · Activo', style: tema.bodySmall?.copyWith(color: colorTextoSuave)),
                      ],
                    ),
                  ),
                for (final i in equipo.invitaciones)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: colorVerdeSuave, borderRadius: BorderRadius.circular(10)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Invitación pendiente',
                          style: tema.labelLarge?.copyWith(color: colorVerdeOscuro, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${i.correo} · ${i.rol.etiqueta}\nEnviada el ${fechaCorta(i.enviada)}',
                          style: tema.bodySmall?.copyWith(color: colorTextoSuave),
                        ),
                      ],
                    ),
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
        const SizedBox(height: 4),
        Text(
          'Cada persona conserva el rol asignado en esta granja.',
          style: tema.bodySmall?.copyWith(color: colorTextoSuave),
        ),
      ],
    );
  }
}
