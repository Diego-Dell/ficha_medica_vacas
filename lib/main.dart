import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'logic/sesion.dart';
import 'screens/acceso_general/login_screen.dart';

Future<void> main() async {
  // 1. Conecta la sesión con Supabase antes de abrir la app.
  WidgetsFlutterBinding.ensureInitialized();
  await Sesion.instance.inicializar();

  // 2. Abre la app en la pantalla de login.
  runApp(const FichaMedicaApp());
}

class FichaMedicaApp extends StatelessWidget {
  const FichaMedicaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VetLink',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF2F5D46),
        useMaterial3: true,
      ),
      locale: const Locale('es'),
      supportedLocales: const [Locale('es')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const LoginScreen(),
    );
  }
}
