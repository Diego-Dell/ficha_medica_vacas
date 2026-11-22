import 'package:flutter/material.dart';

import '../logic/granjas.dart';
import '../models/miembro.dart';
import 'dueno_granja/granja_revision_screen.dart';
import 'dueno_granja/mi_granja_screen.dart';
import 'trabajador/cuidados_hoy_screen.dart';
import 'veterinario/seguimiento_veterinario_screen.dart';
import 'administrador/administracion_screen.dart';

/// 1. Crea la pantalla de inicio que corresponde a cada vínculo (patrón Factory); quien entra a una granja no necesita conocer los roles.
abstract final class InicioPorRol {
  /// 2. Conserva el panel del administrador; los demás roles esperan la confirmación de la granja.
  static Widget crear(Vinculo vinculo) {
    if (Granjas.instance.sesionAdministradora) return AdministracionScreen(granja: vinculo.granja);
    if (!vinculo.granja.confirmada) return GranjaRevisionScreen(granja: vinculo.granja);
    return switch (vinculo.rol) {
      RolMiembro.dueno => const MiGranjaScreen(),
      RolMiembro.veterinario => SeguimientoVeterinarioScreen(granja: vinculo.granja.nombre),
      RolMiembro.trabajador => CuidadosHoyScreen(granja: vinculo.granja.nombre),
    };
  }

  /// 3. Guarda la granja confirmada con su rol y abre su inicio, dejando solo el login detrás.
  static void entrar(BuildContext context, Vinculo vinculo) {
    if (vinculo.granja.confirmada && !Granjas.instance.sesionAdministradora) Granjas.instance.seleccionar(vinculo);
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => crear(vinculo)),
      (ruta) => ruta.isFirst,
    );
  }
}
