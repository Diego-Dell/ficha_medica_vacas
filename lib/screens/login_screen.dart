import 'package:flutter/material.dart';

import '../logic/sesion.dart';

const _verde = Color(0xFF2F5D46);
const _verdeOscuro = Color(0xFF24402F);
const _fondo = Color(0xFFF6F7F0);
const _borde = Color(0xFFDDE1D6);
const _textoSuave = Color(0xFF5F6B60);

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _correo = TextEditingController();
  final _contrasena = TextEditingController();
  bool _enviando = false;

  @override
  void dispose() {
    _correo.dispose();
    _contrasena.dispose();
    super.dispose();
  }

  String? _requerido(String? valor) => (valor == null || valor.trim().isEmpty) ? 'Campo obligatorio' : null;

  void _avisar(String mensaje) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(mensaje)));
  }

  Future<void> _ingresar() async {
    if (_enviando || !_form.currentState!.validate()) return;
    setState(() => _enviando = true);
    final error = await Sesion.instance.iniciar(_correo.text, _contrasena.text);
    if (!mounted) return;
    setState(() => _enviando = false);
    _avisar(error ?? 'Bienvenido, ${Sesion.instance.usuario}');
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    final botonSecundario = OutlinedButton.styleFrom(
      foregroundColor: _verde,
      backgroundColor: Colors.white,
      minimumSize: const Size.fromHeight(48),
      side: const BorderSide(color: _borde),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );

    return Scaffold(
      backgroundColor: _fondo,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _Marca(),
                    const SizedBox(height: 24),
                    Text(
                      'Bienvenido a VetLink',
                      style: tema.headlineSmall?.copyWith(color: _verdeOscuro, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'El cuidado de tu ganado, en un mismo lugar.',
                      style: tema.bodyMedium?.copyWith(color: _textoSuave),
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: AspectRatio(
                        aspectRatio: 2,
                        child: Image.asset(
                          'assets/images/login_vaca.png',
                          fit: BoxFit.cover,
                          semanticLabel: 'Vaca lechera en un potrero',
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _Campo(
                      etiqueta: 'Correo electrónico',
                      child: TextFormField(
                        controller: _correo,
                        decoration: _decoracion(pista: 'ana@ejemplo.com'),
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autocorrect: false,
                        validator: _requerido,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _Campo(
                      etiqueta: 'Contraseña',
                      child: TextFormField(
                        controller: _contrasena,
                        decoration: _decoracion(),
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _ingresar(),
                        validator: _requerido,
                      ),
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: _verde,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _enviando ? null : _ingresar,
                      child: Text(_enviando ? 'Ingresando...' : 'Iniciar sesión'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      style: botonSecundario,
                      onPressed: () => _avisar('Recuperar la contraseña estará disponible pronto'),
                      child: const Text('Olvidé mi contraseña'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      style: botonSecundario,
                      onPressed: () => _avisar('El registro de granjas estará disponible pronto'),
                      child: const Text('Registrar mi granja'),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '¿Sos veterinario o trabajador? Pedile al dueño que te invite por correo.',
                      style: tema.bodySmall?.copyWith(color: _textoSuave),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _decoracion({String? pista}) {
    OutlineInputBorder borde(Color color) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: color),
        );
    return InputDecoration(
      hintText: pista,
      filled: true,
      fillColor: Colors.white,
      enabledBorder: borde(_borde),
      focusedBorder: borde(_verde),
      errorBorder: borde(Colors.red.shade700),
      focusedErrorBorder: borde(Colors.red.shade700),
    );
  }
}

class _Marca extends StatelessWidget {
  const _Marca();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(color: _verde, borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.eco_outlined, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 8),
        Text(
          'VetLink',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(color: _verdeOscuro, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _Campo extends StatelessWidget {
  const _Campo({required this.etiqueta, required this.child});

  final String etiqueta;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(etiqueta, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: _verdeOscuro)),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}
