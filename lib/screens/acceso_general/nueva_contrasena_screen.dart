import 'package:flutter/material.dart';

import '../../logic/sesion.dart';
import '../../widgets/pantalla.dart';
import '../../widgets/vetlink.dart';

/// Se abre desde el enlace del correo de recuperación y guarda la nueva contraseña.
class NuevaContrasenaScreen extends StatefulWidget {
  const NuevaContrasenaScreen({super.key});

  @override
  State<NuevaContrasenaScreen> createState() => _NuevaContrasenaScreenState();
}

class _NuevaContrasenaScreenState extends State<NuevaContrasenaScreen> {
  final _form = GlobalKey<FormState>();
  final _clave = TextEditingController();
  final _confirmacion = TextEditingController();
  bool _mostrar = false;
  bool _enviando = false;

  @override
  void dispose() {
    _clave.dispose();
    _confirmacion.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    // 1. Valida el formulario y evita envíos dobles.
    if (_enviando || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _enviando = true);

    // 2. Guarda la contraseña en la sesión que abrió el enlace.
    final error = await Sesion.instance.cambiarContrasena(_clave.text);
    if (!mounted) return;
    setState(() => _enviando = false);

    // 3. Muestra el error o cierra la sesión del enlace y vuelve al login.
    if (error != null) {
      avisar(context, error);
      return;
    }
    await Sesion.instance.cerrar();
    if (!mounted) return;
    avisar(context, 'Tu contraseña se actualizó. Iniciá sesión con la nueva');
    Navigator.popUntil(context, (ruta) => ruta.isFirst);
  }

  @override
  Widget build(BuildContext context) => Pantalla(
    titulo: 'Nueva contraseña',
    subtitulo: 'Creá una nueva contraseña para recuperar el acceso.',
    children: [
      Form(
        key: _form,
        child: Column(
          children: [
            CampoEtiquetado(
              etiqueta: 'Nueva contraseña',
              child: TextFormField(
                controller: _clave,
                obscureText: !_mostrar,
                autocorrect: false,
                enableSuggestions: false,
                textInputAction: TextInputAction.next,
                decoration: decoracionCampo(icono: 'candado').copyWith(
                  suffixIcon: IconButton(
                    tooltip: _mostrar
                        ? 'Ocultar contraseña'
                        : 'Mostrar contraseña',
                    onPressed: () => setState(() => _mostrar = !_mostrar),
                    icon: Icon(
                      _mostrar ? Icons.visibility_off : Icons.visibility,
                    ),
                  ),
                ),
                validator: (valor) =>
                    requerido(valor) ??
                    ((valor?.length ?? 0) < 8
                        ? 'Usá al menos 8 caracteres'
                        : null),
              ),
            ),
            CampoEtiquetado(
              etiqueta: 'Confirmar contraseña',
              child: TextFormField(
                controller: _confirmacion,
                obscureText: !_mostrar,
                autocorrect: false,
                enableSuggestions: false,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _guardar(),
                decoration: decoracionCampo(icono: 'candado'),
                validator: (valor) =>
                    requerido(valor) ??
                    (valor != _clave.text
                        ? 'Las contraseñas no coinciden'
                        : null),
              ),
            ),
          ],
        ),
      ),
      const Text(
        'Usá al menos 8 caracteres.',
        style: TextStyle(color: colorTextoSuave, fontSize: 12),
      ),
      const SizedBox(height: 24),
      BotonPrincipal(
        texto: _enviando ? 'Guardando...' : 'Guardar contraseña',
        alPresionar: _enviando ? null : _guardar,
      ),
      BotonSecundario(
        texto: 'Volver al login',
        alPresionar: () => Navigator.popUntil(context, (ruta) => ruta.isFirst),
      ),
    ],
  );
}
