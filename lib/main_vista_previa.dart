import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/acceso_general/login_screen.dart';
import 'screens/acceso_general/nueva_contrasena_screen.dart';
import 'screens/administrador/administracion_screen.dart';
import 'screens/trabajador/cuidados_hoy_screen.dart';
import 'screens/veterinario/seguimiento_veterinario_screen.dart';
import 'widgets/pantalla.dart';
import 'widgets/vetlink.dart';

/// Entrada independiente para revisar las pantallas sin cuenta ni Supabase.
void main() => runApp(const VistaPreviaApp());

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
    // En esta vista, cerrar sesión vuelve al selector; no hay una sesión real.
    void salir() => Navigator.popUntil(context, (ruta) => ruta.isFirst);
    return Pantalla(
      titulo: 'Vista previa',
      volver: false,
      subtitulo:
          'Vistas de la interfaz. No se conecta al servidor ni guarda cambios.',
      children: [
        BotonPrincipal(
          texto: 'Nueva contraseña',
          alPresionar: () => abrir(const NuevaContrasenaScreen()),
        ),
        BotonSecundario(
          texto: 'Veterinario',
          alPresionar: () => abrir(
            SeguimientoVeterinarioScreen(
              granja: 'Granja seleccionada',
              alCerrarSesion: salir,
            ),
          ),
        ),
        BotonSecundario(
          texto: 'Trabajador',
          alPresionar: () => abrir(
            CuidadosHoyScreen(
              granja: 'Granja seleccionada',
              alCerrarSesion: salir,
            ),
          ),
        ),
        BotonSecundario(
          texto: 'Administrador',
          alPresionar: () => abrir(
            AdministracionScreen(vistaPrevia: true, alCerrarSesion: salir),
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
