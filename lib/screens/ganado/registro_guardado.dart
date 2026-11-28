import 'package:flutter/material.dart';

import '../../logic/granjas.dart';
import '../../logic/sincronizacion.dart';
import '../../widgets/vetlink.dart';

// 1. Ventana "Registro guardado"; sin conexión avisa que quedó en el dispositivo (RF-07).
Future<void> mostrarRegistroGuardado(BuildContext context, {EstadoRegistro? estado}) {
  final enDispositivo = estado == EstadoRegistro.guardadoEnDispositivo;
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => VentanaVetLink(
      icono: enDispositivo ? 'sincronizado' : 'check',
      titulo: enDispositivo ? EstadoRegistro.guardadoEnDispositivo.etiqueta : 'Registro guardado',
      texto: enDispositivo
          ? 'No hay conexión. El registro de ${Granjas.instance.actual.nombre} quedó pendiente y se enviará solo al recuperar internet. Podés verlo en Perfil › Sincronización.'
          : 'La información de ${Granjas.instance.actual.nombre} se guardó correctamente.',
      acciones: [BotonPrincipal(texto: 'Continuar', alPresionar: () => Navigator.pop(context))],
    ),
  );
}
