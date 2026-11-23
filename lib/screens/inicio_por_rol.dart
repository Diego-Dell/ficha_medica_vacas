import 'package:flutter/material.dart';

import '../logic/granjas.dart';
import '../models/miembro.dart';
import 'dueno_granja/granja_revision_screen.dart';
import 'dueno_granja/mi_granja_screen.dart';
import 'trabajador/cuidados_hoy_screen.dart';
import 'veterinario/seguimiento_veterinario_screen.dart';
import 'administrador/administracion_screen.dart';

// 1. Elige la pantalla de inicio según el rol (Factory).
abstract final class InicioPorRol {
  // 2. Nombre de la ruta de inicio, para volver a ella.
  static const ruta = 'inicio';

  // 3. El administrador va a su panel; sin confirmar, a la revisión.
  static Widget crear(Vinculo vinculo) {
    if (Granjas.instance.sesionAdministradora) return AdministracionScreen(granja: vinculo.granja);
    if (!vinculo.granja.confirmada) return GranjaRevisionScreen(granja: vinculo.granja);
    return switch (vinculo.rol) {
      RolMiembro.dueno => const MiGranjaScreen(),
      RolMiembro.veterinario => SeguimientoVeterinarioScreen(granja: vinculo.granja.nombre),
      RolMiembro.trabajador => CuidadosHoyScreen(granja: vinculo.granja.nombre),
    };
  }

  // 4. Guarda granja y rol y abre el inicio sobre el login.
  static void entrar(BuildContext context, Vinculo vinculo) {
    if (vinculo.granja.confirmada && !Granjas.instance.sesionAdministradora) Granjas.instance.seleccionar(vinculo);
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(settings: const RouteSettings(name: ruta), builder: (_) => crear(vinculo)),
      (ruta) => ruta.isFirst,
    );
  }
}
