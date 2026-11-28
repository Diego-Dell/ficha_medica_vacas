import 'package:flutter/material.dart';

import '../../logic/granjas.dart';
import '../../logic/sesion.dart';
import '../../models/miembro.dart';
import '../../widgets/vetlink.dart';

class ExpulsarMiembroScreen extends StatefulWidget {
  const ExpulsarMiembroScreen({super.key, required this.miembros});

  final List<Miembro> miembros;

  @override
  State<ExpulsarMiembroScreen> createState() => _ExpulsarMiembroScreenState();
}

class _ExpulsarMiembroScreenState extends State<ExpulsarMiembroScreen> {
  Miembro? _seleccionado;
  bool _enviando = false;
  bool _expulsado = false;

  Future<void> _expulsar() async {
    final miembro = _seleccionado;
    if (_enviando || miembro == null) return;
    setState(() => _enviando = true);
    final error = await Granjas.instance.expulsar(miembro);
    if (!mounted) return;
    setState(() {
      _enviando = false;
      _expulsado = error == null;
    });
    if (error != null) avisar(context, error);
  }

  @override
  Widget build(BuildContext context) {
    final datos = Granjas.instance;
    final granja = datos.actual.nombre;
    final miembros = widget.miembros
        .where((m) => m.rol != RolMiembro.dueno && m.cuentaId.isNotEmpty && m.cuentaId != Sesion.instance.id)
        .toList();
    void volver() => Navigator.pop(context, _expulsado);

    return PantallaVetLink(
      encabezado: EncabezadoVetLink(granja: granja, alVolver: _enviando ? null : volver),
      titulo: _expulsado ? 'Miembro expulsado' : 'Expulsar miembro',
      subtitulo: _expulsado
          ? '${_seleccionado!.nombre} ya no tiene acceso a $granja.'
          : 'Seleccioná a quién querés quitar de $granja.',
      children: [
        if (!_expulsado) ...[
          if (miembros.isEmpty || datos.rol != RolMiembro.dueno)
            const Text('No hay miembros que puedas expulsar.')
          else ...[
            CampoEtiquetado(
              etiqueta: 'Miembro de la granja *',
              child: DropdownButtonFormField<Miembro>(
                initialValue: _seleccionado,
                isExpanded: true,
                decoration: decoracionCampo(pista: 'Seleccionar miembro', icono: 'perfil'),
                items: [
                  for (final m in miembros)
                    DropdownMenuItem(
                      value: m,
                      child: Text('${m.nombre} · ${m.rol.etiqueta}', overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: _enviando ? null : (m) => setState(() => _seleccionado = m),
              ),
            ),
            const AvisoVetLink(
              titulo: '¿Qué pasa al expulsarlo?',
              texto: 'Perderá el acceso a esta granja. Su cuenta y los registros que realizó se conservarán.',
              advertencia: true,
            ),
            BotonPrincipal(
              color: colorRojo,
              texto: _enviando ? 'Expulsando...' : 'Confirmar expulsión',
              alPresionar: _enviando || _seleccionado == null ? null : _expulsar,
            ),
          ],
        ],
        BotonSecundario(texto: _expulsado ? 'Volver a miembros' : 'Cancelar', alPresionar: _enviando ? null : volver),
      ],
    );
  }
}
