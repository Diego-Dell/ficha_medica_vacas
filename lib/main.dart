import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'logic/sesion.dart';
import 'screens/acceso_general/login_screen.dart';
import 'screens/acceso_general/restablecer_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Sesion.instance.inicializar();
  final uri = Uri.base;
  final tokenRestablecer =
      uri.queryParameters['restablecer'] ?? _tokenDesdeRuta(uri);
  runApp(FichaMedicaApp(tokenRestablecer: tokenRestablecer));
}

String? _tokenDesdeRuta(Uri uri) {
  final partes = uri.pathSegments;
  final indice = partes.indexOf('restablecer');
  if (indice < 0 || indice + 1 >= partes.length) return null;
  return partes[indice + 1];
}

class FichaMedicaApp extends StatefulWidget {
  const FichaMedicaApp({super.key, this.tokenRestablecer});

  final String? tokenRestablecer;

  @override
  State<FichaMedicaApp> createState() => _FichaMedicaAppState();
}

class _FichaMedicaAppState extends State<FichaMedicaApp> {
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
      home: widget.tokenRestablecer != null
          ? RestablecerScreen(token: widget.tokenRestablecer)
          : const LoginScreen(),
    );
  }
}
