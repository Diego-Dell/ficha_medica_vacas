import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'logic/granjas.dart';
import 'models/granja.dart';
import 'models/miembro.dart';
import 'screens/acceso_general/login_screen.dart';
import 'screens/trabajador/cuidados_hoy_screen.dart';
import 'screens/veterinario/seguimiento_veterinario_screen.dart';
import 'widgets/pantalla.dart';
import 'widgets/vetlink.dart';

/// Entrada independiente para revisar las pantallas sin cuenta ni Supabase.
void main() => runApp(const VistaPreviaApp());

/// Granja de ejemplo: las pantallas de fichas necesitan una granja elegida aunque no haya Supabase.
const _losPinos = Granja(
  id: 'vista-previa',
  nombre: 'Los Pinos',
  dueno: 'Ana Pérez',
  superficie: 18,
  runsa: 'SC-02418',
  documento: '',
  confirmada: true,
);

class VistaPreviaApp extends StatelessWidget {
  const VistaPreviaApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(colorSchemeSeed: colorVerde, useMaterial3: true),
    locale: const Locale('es'),
    supportedLocales: const [Locale('es')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: const _Selector(),
  );
}

class _Selector extends StatelessWidget {
  const _Selector();

  @override
  Widget build(BuildContext context) {
    void abrir(Widget pantalla) =>
        Navigator.push(context, MaterialPageRoute(builder: (_) => pantalla));
    // 1. Elige la granja de ejemplo con el rol del panel antes de abrirlo.
    void abrirComo(RolMiembro rol, Widget pantalla) {
      Granjas.instance.seleccionar((granja: _losPinos, rol: rol));
      abrir(pantalla);
    }

    // En esta vista, cerrar sesión vuelve al selector; no hay una sesión real.
    void salir() => Navigator.popUntil(context, (ruta) => ruta.isFirst);
    return Pantalla(
      titulo: 'Vista previa',
      volver: false,
      subtitulo:
          'Datos de ejemplo. No se conecta a Supabase ni guarda cambios.',
      children: [
        BotonPrincipal(
          texto: 'Veterinario',
          alPresionar: () => abrirComo(RolMiembro.veterinario, 
            SeguimientoVeterinarioScreen(
              granja: 'Los Pinos',
              alCerrarSesion: salir,
            ),
          ),
        ),
        BotonSecundario(
          texto: 'Trabajador',
          alPresionar: () => abrirComo(RolMiembro.trabajador, 
            CuidadosHoyScreen(granja: 'Los Pinos', alCerrarSesion: salir),
          ),
        ),
        BotonSecundario(
          texto: 'Ver login',
          alPresionar: () => abrir(const LoginScreen()),
        ),
      ],
    );
  }
}
