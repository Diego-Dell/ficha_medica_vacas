import 'package:flutter/material.dart';

import 'logic/sesion.dart';
import 'screens/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Sesion.instance.inicializar();
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
      home: const LoginScreen(),
    );
  }
}
