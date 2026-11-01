import 'package:flutter/material.dart';

import 'screens/login_screen.dart';

void main() {
  runApp(const FichaMedicaApp());
}

class FichaMedicaApp extends StatelessWidget {
  const FichaMedicaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ficha médica de vacas',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF2E7D32),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}
