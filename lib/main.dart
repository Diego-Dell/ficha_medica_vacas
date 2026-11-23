import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'logic/sesion.dart';
import 'screens/acceso_general/login_screen.dart';
import 'screens/acceso_general/nueva_contrasena_screen.dart';
import 'widgets/vetlink.dart';

/// Permite abrir pantallas desde fuera de un widget, como el enlace de recuperación.
final navegador = GlobalKey<NavigatorState>();

/// Espera a que el navegador esté montado, incluso al iniciar desde el correo.
void abrirRecuperacion() {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    navegador.currentState?.push(MaterialPageRoute(builder: (_) => const NuevaContrasenaScreen()));
  });
  WidgetsBinding.instance.ensureVisualUpdate();
}

Future<void> main() async {
  // 1. Conecta la sesión con Supabase antes de abrir la app.
  WidgetsFlutterBinding.ensureInitialized();
  await Sesion.instance.inicializar();

  // 2. Si la app se abre desde el correo de recuperación, muestra Nueva contraseña.
  Sesion.instance.alRecuperar(abrirRecuperacion);

  // 3. Abre la app en la pantalla de login.
  runApp(const FichaMedicaApp());
}

class FichaMedicaApp extends StatelessWidget {
  const FichaMedicaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VetLink',
      navigatorKey: navegador,
      debugShowCheckedModeBanner: false,
      theme: temaVetLink(),
      locale: const Locale('es'),
      supportedLocales: const [Locale('es')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const LoginScreen(),
    );
  }
}
