import 'package:flutter/material.dart';

import '../../widgets/pantalla.dart';
import '../../widgets/vetlink.dart';

/// Formulario listo para conectar al enlace de recuperación; no cambia cuentas.
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

  @override
  void dispose() {
    _clave.dispose();
    _confirmacion.dispose();
    super.dispose();
  }

  void _guardar() {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    avisar(
      context,
      'Las contraseñas coinciden. El guardado aún no está conectado.',
    );
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
                decoration: decoracionCampo().copyWith(
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
                decoration: decoracionCampo(),
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
      BotonPrincipal(texto: 'Guardar contraseña', alPresionar: _guardar),
      BotonSecundario(
        texto: 'Volver al login',
        alPresionar: () => Navigator.popUntil(context, (ruta) => ruta.isFirst),
      ),
    ],
  );
}
