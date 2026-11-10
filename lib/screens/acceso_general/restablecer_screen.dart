import 'package:flutter/material.dart';

import '../../logic/sesion.dart';
import '../../widgets/pantalla.dart';
import '../../widgets/vetlink.dart';
import 'login_screen.dart';

class RestablecerScreen extends StatefulWidget {
  const RestablecerScreen({super.key, this.token});

  /// Token de un solo uso incluido en el enlace enviado por Mailgun.
  final String? token;

  @override
  State<RestablecerScreen> createState() => _RestablecerScreenState();
}

class _RestablecerScreenState extends State<RestablecerScreen> {
  final _form = GlobalKey<FormState>();
  final _contrasena = TextEditingController();
  final _confirmacion = TextEditingController();
  bool _enviando = false;
  bool _actualizada = false;

  bool get _enlaceValido => widget.token != null && widget.token!.isNotEmpty;

  @override
  void dispose() {
    _contrasena.dispose();
    _confirmacion.dispose();
    super.dispose();
  }

  String? _validarContrasena(String? valor) {
    final longitud = (valor ?? '').length;
    if (longitud < 6) return 'Mínimo 6 caracteres';
    if (longitud > 200) return 'Máximo 200 caracteres';
    return null;
  }

  String? _validarConfirmacion(String? valor) =>
      valor != _contrasena.text ? 'Las contraseñas no coinciden' : null;

  Future<void> _guardar() async {
    if (_enviando || !_form.currentState!.validate()) return;
    setState(() => _enviando = true);

    final error = await Sesion.instance.restablecer(
      widget.token!,
      _contrasena.text,
    );
    if (!mounted) return;
    setState(() {
      _enviando = false;
      _actualizada = error == null;
    });
    if (error != null) avisar(context, error);
  }

  void _volverAlLogin() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_enlaceValido) {
      return Pantalla(
        titulo: 'Enlace no válido',
        subtitulo: 'Solicita otro correo para restablecer tu contraseña.',
        volver: false,
        children: [
          BotonPrincipal(
            texto: 'Volver al inicio de sesión',
            alPresionar: _volverAlLogin,
          ),
        ],
      );
    }

    return Pantalla(
      titulo: _actualizada
          ? 'Contraseña actualizada'
          : 'Restablecer contraseña',
      subtitulo: _actualizada
          ? 'Los cambios se guardaron correctamente. Inicia sesión con tu nueva contraseña; VetLink abrirá el panel que corresponde a tu cuenta.'
          : 'Elige una contraseña nueva para tu cuenta de VetLink.',
      volver: !_actualizada,
      children: _actualizada
          ? [
              BotonPrincipal(
                texto: 'Volver al inicio de sesión',
                alPresionar: _volverAlLogin,
              ),
            ]
          : [
              Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    CampoEtiquetado(
                      etiqueta: 'Nueva contraseña',
                      child: TextFormField(
                        controller: _contrasena,
                        decoration: decoracionCampo(),
                        obscureText: true,
                        textInputAction: TextInputAction.next,
                        validator: _validarContrasena,
                      ),
                    ),
                    CampoEtiquetado(
                      etiqueta: 'Confirmar contraseña',
                      child: TextFormField(
                        controller: _confirmacion,
                        decoration: decoracionCampo(),
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _guardar(),
                        validator: _validarConfirmacion,
                      ),
                    ),
                  ],
                ),
              ),
              BotonPrincipal(
                texto: _enviando ? 'Guardando...' : 'Guardar contraseña',
                alPresionar: _enviando ? null : _guardar,
              ),
              const Text(
                'El enlace vence en una hora y solo se puede usar una vez.',
                style: TextStyle(color: colorTextoSuave, fontSize: 12),
              ),
            ],
    );
  }
}
