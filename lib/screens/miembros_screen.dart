import 'package:flutter/material.dart';

import '../logic/granjas.dart';
import '../widgets/vetlink.dart';

class MiembrosScreen extends StatefulWidget {
  const MiembrosScreen({super.key});

  @override
  State<MiembrosScreen> createState() => _MiembrosScreenState();
}

class _MiembrosScreenState extends State<MiembrosScreen> {
  @override
  Widget build(BuildContext context) {
    final datos = Granjas.instance;
    final tema = Theme.of(context).textTheme;
    void volver() => Navigator.pop(context);

    return PantallaVetLink(
      encabezado: EncabezadoVetLink(granja: datos.actual.nombre, alVolver: volver),
      barraInferior: BarraVetLink(alVolver: volver),
      titulo: 'Miembros',
      subtitulo: 'Equipo vinculado a ${datos.actual.nombre}.',
      children: [
        for (final m in datos.miembros)
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
        for (final i in datos.invitaciones)
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
                  '${i.nombre ?? i.correo} · ${i.rol.etiqueta}\nEnviada el ${fechaCorta(i.enviada)}',
                  style: tema.bodySmall?.copyWith(color: colorTextoSuave),
                ),
              ],
            ),
          ),
        const SizedBox(height: 4),
        BotonPrincipal(
          texto: 'Invitar persona',
          alPresionar: () => avisar(context, 'Invitar persona estará disponible pronto'),
        ),
        BotonSecundario(
          texto: 'Reenviar invitación',
          alPresionar: () => avisar(context, 'Reenviar invitaciones estará disponible pronto'),
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
