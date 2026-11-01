import 'package:flutter/material.dart';

import '../logic/sesion.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _usuario = TextEditingController();
  final _contrasena = TextEditingController();
  bool _oculta = true;

  @override
  void dispose() {
    _usuario.dispose();
    _contrasena.dispose();
    super.dispose();
  }

  String? _requerido(String? valor) => (valor == null || valor.trim().isEmpty) ? 'Campo obligatorio' : null;

  void _ingresar() {
    if (!_form.currentState!.validate()) return;
    final ok = Sesion.instance.iniciar(_usuario.text, _contrasena.text);
    final mensaje = ok ? 'Bienvenido, ${Sesion.instance.usuario}' : 'Usuario o contraseña incorrectos';
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(mensaje)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Iniciar sesión',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _usuario,
                      decoration: const InputDecoration(labelText: 'Usuario', border: OutlineInputBorder()),
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      validator: _requerido,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _contrasena,
                      decoration: InputDecoration(
                        labelText: 'Contraseña',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          tooltip: _oculta ? 'Mostrar contraseña' : 'Ocultar contraseña',
                          icon: Icon(_oculta ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                          onPressed: () => setState(() => _oculta = !_oculta),
                        ),
                      ),
                      obscureText: _oculta,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _ingresar(),
                      validator: _requerido,
                    ),
                    const SizedBox(height: 24),
                    FilledButton(onPressed: _ingresar, child: const Text('Ingresar')),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
