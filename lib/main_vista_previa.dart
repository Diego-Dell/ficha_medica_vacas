import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'models/miembro.dart';
import 'preview/datos_vista_previa.dart';
import 'screens/tratamientos_prevencion_screen.dart';
import 'widgets/vetlink.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  WidgetsBinding.instance.ensureSemantics();
  final datos = DatosVistaPrevia();
  await datos.inicializar();
  runApp(VistaPreviaApp(datos: datos));
}

class VistaPreviaApp extends StatefulWidget {
  const VistaPreviaApp({super.key, required this.datos});
  final DatosVistaPrevia datos;
  @override
  State<VistaPreviaApp> createState() => _VistaPreviaAppState();
}

class _VistaPreviaAppState extends State<VistaPreviaApp> {
  RolMiembro _rol = RolMiembro.veterinario;
  final _navegador = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Tratamientos y prevención',
    navigatorKey: _navegador,
    debugShowCheckedModeBanner: false,
    theme: temaVetLink(),
    locale: const Locale('es'),
    supportedLocales: const [Locale('es')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    builder: (context, child) => Column(
      children: [
        Material(
          color: colorAmbarFondo,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Datos simulados',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      final rol = _rol == RolMiembro.veterinario
                          ? RolMiembro.trabajador
                          : RolMiembro.veterinario;
                      _navegador.currentState?.popUntil((ruta) => ruta.isFirst);
                      widget.datos.seleccionar(rol);
                      setState(() => _rol = rol);
                    },
                    child: Text(
                      'Cambiar a ${_rol == RolMiembro.veterinario ? 'Trabajador' : 'Veterinario'}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(child: child!),
      ],
    ),
    home: TratamientosPrevencionScreen(key: ValueKey(_rol)),
  );
}
