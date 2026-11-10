import 'package:flutter/material.dart';

import '../../logic/granjas.dart';
import '../../logic/sesion.dart';
import '../../models/miembro.dart';
import '../administrador/administracion_screen.dart';
import '../trabajador/cuidados_hoy_screen.dart';
import '../veterinario/seguimiento_veterinario_screen.dart';
import '../../widgets/vetlink.dart';
import '../../widgets/pantalla.dart';
import 'crear_cuenta_screen.dart';
import '../dueno_granja/granja_revision_screen.dart';
import '../dueno_granja/mi_granja_screen.dart';
import 'recuperar_screen.dart';
import '../dueno_granja/registrar_granja_screen.dart';

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

  Future<void> _ingresar() async {
    // 1. Valida el formulario y evita envíos dobles.
    if (_enviando || !_form.currentState!.validate()) return;
    setState(() => _enviando = true);

    // 2. Pide al servidor iniciar la sesión.
    final error = await Sesion.instance.iniciar(_correo.text, _contrasena.text);
    if (!mounted) return;

    // 3. Muestra el error o abre la pantalla que corresponde a la cuenta.
    if (error != null) {
      avisar(context, error);
    } else {
      await _entrar();
    }
    if (mounted) setState(() => _enviando = false);
  }

  Future<void> _entrar() async {
    try {
      // El administrador técnico no necesita pertenecer a una granja.
      final administrador = await Granjas.instance.esAdministrador();
      if (!mounted) return;
      if (administrador) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AdministracionScreen(
              alCerrarSesion: () =>
                  Navigator.popUntil(context, (ruta) => ruta.isFirst),
            ),
          ),
        );
        return;
      }

      // 1. Pregunta por las invitaciones pendientes de la cuenta.
      await _atenderInvitaciones();

      // 2. Busca las granjas de la cuenta.
      final vinculos = await Granjas.instance.misVinculos();
      if (!mounted) return;

      // 3. Entra a la primera granja confirmada.
      final confirmado = vinculos.where((v) => v.granja.confirmada).firstOrNull;
      if (confirmado != null) {
        Granjas.instance.seleccionar(confirmado);
        final pantalla = switch (confirmado.rol) {
          RolMiembro.dueno => const MiGranjaScreen(),
          RolMiembro.veterinario => SeguimientoVeterinarioScreen(
            granja: confirmado.granja.nombre,
          ),
          RolMiembro.trabajador => CuidadosHoyScreen(
            granja: confirmado.granja.nombre,
          ),
        };
        Navigator.push(context, MaterialPageRoute(builder: (_) => pantalla));
        return;
      }

      // 4. Si ninguna está confirmada, muestra la que sigue en revisión.
      if (vinculos.isNotEmpty) {
        final granja = vinculos.first.granja;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GranjaRevisionScreen(granja: granja),
          ),
        );
        return;
      }

      // 5. Avisa si la cuenta todavía no tiene granjas.
      avisar(context, 'Tu cuenta todavía no tiene una granja');
    } on Exception {
      if (mounted) {
        avisar(context, 'No se pudieron cargar tus granjas. Intenta de nuevo');
      }
    }
  }

  Future<void> _atenderInvitaciones() async {
    for (final invitacion in await Granjas.instance.misInvitaciones()) {
      if (!mounted) return;
      final acepta = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Tienes una invitación'),
          content: Text(
            'Te invitaron a una granja como ${invitacion.rol.etiqueta}. ¿Quieres unirte?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Ahora no'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Aceptar'),
            ),
          ],
        ),
      );
      if (acepta ?? false) await Granjas.instance.aceptarInvitacion(invitacion);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Pantalla(
      titulo: 'Bienvenido a VetLink',
      volver: false,
      subtitulo: 'El cuidado de tu ganado, en un mismo lugar.',
      children: [
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
        const SizedBox(height: 8),
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CampoEtiquetado(
                etiqueta: 'Correo electrónico',
                child: TextFormField(
                  controller: _correo,
                  decoration: decoracionCampo(),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  validator: requerido,
                ),
              ),
              CampoEtiquetado(
                etiqueta: 'Contraseña',
                child: TextFormField(
                  controller: _contrasena,
                  decoration: decoracionCampo(),
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _ingresar(),
                  validator: requerido,
                ),
              ),
            ],
          ),
        ),
        BotonPrincipal(
          texto: _enviando ? 'Ingresando...' : 'Iniciar sesión',
          alPresionar: _enviando ? null : _ingresar,
        ),
        BotonSecundario(
          texto: 'Olvidé mi contraseña',
          alPresionar: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const RecuperarScreen()),
          ),
        ),
        BotonSecundario(
          texto: 'Registrar mi granja',
          alPresionar: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const RegistrarGranjaScreen()),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '¿Sos veterinario o trabajador? Pedile al dueño que te invite por correo.',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: colorTextoSuave),
        ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: colorVerde),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CrearCuentaScreen()),
          ),
          child: const Text('Me invitaron: crear cuenta'),
        ),
      ],
    );
  }
}
