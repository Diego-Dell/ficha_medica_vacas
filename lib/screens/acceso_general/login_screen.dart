import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../logic/granjas.dart';
import '../../logic/sesion.dart';
import '../administrador/administracion_screen.dart';
import '../../widgets/vetlink.dart';
import '../../widgets/pantalla.dart';
import '../inicio_por_rol.dart';
import 'crear_cuenta_screen.dart';
import 'recuperar_screen.dart';
import '../dueno_granja/registrar_granja_screen.dart';
import 'seleccionar_granja_screen.dart';
import 'aceptar_invitacion_screen.dart';

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
  StreamSubscription<AuthState>? _enlaces;
  bool _abriendoInvitacion = false;

  @override
  void initState() {
    super.initState();

    // 1. Si la app se abre desde el enlace de confirmación, entra directo a la cuenta ya confirmada.
    _enlaces = Sesion.instance.alAbrirEnlace(
      alInvitar: () {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _abrirInvitacion();
        });
        WidgetsBinding.instance.ensureVisualUpdate();
      },
      alConfirmar: () {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          Navigator.popUntil(context, (ruta) => ruta.isFirst);
          avisar(context, 'Tu correo quedó confirmado');
          _entrar();
        });
        WidgetsBinding.instance.ensureVisualUpdate();
      },
      alFallar: (mensaje) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) avisar(context, mensaje);
        });
        WidgetsBinding.instance.ensureVisualUpdate();
      },
    );
  }

  @override
  void dispose() {
    Sesion.instance.dejarDeEscucharEnlaces();
    _enlaces?.cancel();
    _correo.dispose();
    _contrasena.dispose();
    super.dispose();
  }

  Future<void> _abrirInvitacion() async {
    if (_abriendoInvitacion) return;
    _abriendoInvitacion = true;
    try {
      if (Sesion.instance.iniciada) {
        final invitaciones = await Granjas.instance.misInvitaciones();
        if (!mounted) return;
        if (invitaciones.isNotEmpty) {
          Navigator.popUntil(context, (ruta) => ruta.isFirst);
          await _entrar();
          return;
        }
        final cambiar = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
          title: const Text('Abrir invitación'),
          content: Text('La sesión abierta es ${Sesion.instance.usuario}. Para aceptar la invitación usá el correo que la recibió.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Volver')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Cambiar cuenta')),
          ],
        ));
        if (cambiar != true || !mounted) return;
        await Sesion.instance.cerrar();
        if (!mounted) return;
      }
      Navigator.popUntil(context, (ruta) => ruta.isFirst);
      await Navigator.push(context, MaterialPageRoute(builder: (_) => const CrearCuentaScreen()));
    } on Exception {
      if (mounted) avisar(context, 'No se pudo consultar la invitación. Revisá la conexión e intentá nuevamente');
    } finally {
      _abriendoInvitacion = false;
    }
  }

  Future<void> _ingresar() async {
    // 1. Valida el formulario y evita envíos dobles.
    if (_enviando || !_form.currentState!.validate()) return;
    setState(() => _enviando = true);

    // 2. Pide a Supabase iniciar la sesión.
    final error = await Sesion.instance.iniciar(_correo.text, _contrasena.text);
    if (!mounted) return;

    // 3. Muestra el error o abre la pantalla que corresponde a la cuenta.
    if (error != null) {
      if (error == 'Falta confirmar el correo') {
        final correo = _correo.text.trim();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error),
          action: SnackBarAction(label: 'Reenviar correo', onPressed: () async {
            final fallo = await Sesion.instance.reenviarConfirmacion(correo);
            if (mounted) avisar(context, fallo ?? 'Se solicitó el correo de confirmación. Revisá tu correo y spam');
          })));
      } else {
        avisar(context, error);
      }
    } else {
      await _entrar();
    }
    if (mounted) setState(() => _enviando = false);
  }

  Future<void> _entrar() async {
    try {
      // 1. El administrador técnico no necesita pertenecer a una granja.
      final administrador = await Granjas.instance.esAdministrador();
      if (!mounted) return;
      if (administrador) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const AdministracionScreen()));
        return;
      }

      final errorDocumento = await Granjas.instance.subirDocumentosPendientes();
      if (errorDocumento != null && mounted) avisar(context, errorDocumento);

      // 2. Pregunta por las invitaciones pendientes de la cuenta.
      await _atenderInvitaciones();

      // 3. Busca las granjas de la cuenta.
      final vinculos = await Granjas.instance.misVinculos();
      if (!mounted) return;

      // 4. Avisa si la cuenta todavía no tiene granjas.
      if (vinculos.isEmpty) {
        avisar(context, 'Tu cuenta todavía no tiene una granja');
        return;
      }

      // 5. Con varias granjas confirmadas pide elegir una; con una sola entra directo y, si ninguna está confirmada, muestra la revisión.
      final confirmados = vinculos.where((v) => v.granja.confirmada).toList();
      if (confirmados.length > 1) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => SeleccionarGranjaScreen(vinculos: vinculos)));
        return;
      }
      InicioPorRol.entrar(context, confirmados.firstOrNull ?? vinculos.first);
    } on Exception {
      if (mounted) avisar(context, 'No se pudieron cargar tus granjas. Intenta de nuevo');
    }
  }

  Future<void> _atenderInvitaciones() async {
    for (final invitacion in await Granjas.instance.misInvitaciones()) {
      if (!mounted) return;
      final acepta = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => AceptarInvitacionScreen(invitacion: invitacion)),
      );
      if (!(acepta ?? false)) continue;

      // 1. Si la invitación ya no está vigente, avisa y sigue con las demás.
      final error = await Granjas.instance.aceptarInvitacion(invitacion);
      if (error != null && mounted) avisar(context, error);
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
          alPresionar: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RecuperarScreen())),
        ),
        BotonSecundario(
          texto: 'Registrar mi granja',
          alPresionar: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegistrarGranjaScreen())),
        ),
        const SizedBox(height: 4),
        Text(
          '¿Sos veterinario o trabajador? Pedile al dueño que te invite por correo.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorTextoSuave),
        ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: colorVerde),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CrearCuentaScreen())),
          child: const Text('Me invitaron: crear cuenta'),
        ),
      ],
    );
  }
}
