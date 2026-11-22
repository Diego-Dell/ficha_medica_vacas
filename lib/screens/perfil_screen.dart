import 'package:flutter/material.dart';

import '../logic/sesion.dart';
import '../widgets/vetlink.dart';

// 1. Pestaña Perfil: datos de la cuenta, cambiar contraseña y cerrar sesión.
class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key, required this.rol, required this.granja, required this.alCerrarSesion});

  final String rol, granja;
  final VoidCallback alCerrarSesion;

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  bool _enviando = false;

  // 2. Envía el correo para crear una nueva contraseña.
  Future<void> _cambiarContrasena() async {
    final correo = Sesion.instance.usuario;
    if (_enviando || correo == null) return;
    setState(() => _enviando = true);
    final error = await Sesion.instance.recuperar(correo);
    if (!mounted) return;
    setState(() => _enviando = false);
    avisar(context, error ?? 'Te enviamos un correo a $correo para cambiar tu contraseña');
  }

  String get _iniciales {
    final partes = Sesion.instance.nombre.split(RegExp(r'[\s@.]')).where((p) => p.isNotEmpty).toList();
    return partes.take(2).map((p) => p[0].toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              Text('Perfil', style: tema.headlineSmall),
              const SizedBox(height: 16),
              Tarjeta(
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: colorVerde,
                      // 4. Sin nombre muestra el ícono de perfil.
                      child: _iniciales.isEmpty
                          ? const Icono('perfil', color: Colors.white, tam: 28)
                          : Text(
                              _iniciales,
                              style: const TextStyle(
                                fontFamily: fuenteTitulos,
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(Sesion.instance.nombre, style: tema.titleMedium),
                          if (Sesion.instance.usuario != null) Text(Sesion.instance.usuario!, style: tema.bodySmall),
                          const SizedBox(height: 6),
                          ChipEstado('${widget.rol} · ${widget.granja}'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text('CUENTA', style: tema.bodySmall?.copyWith(letterSpacing: .5)),
              const SizedBox(height: 8),
              Tarjeta(
                relleno: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Column(
                  children: [
                    _Fila(
                      icono: 'candado',
                      titulo: _enviando ? 'Enviando correo...' : 'Cambiar contraseña',
                      alPresionar: _cambiarContrasena,
                    ),
                    const Divider(height: 1, color: colorBorde),
                    _Fila(
                      icono: 'cerrar_sesion',
                      titulo: 'Cerrar sesión',
                      peligro: true,
                      alPresionar: widget.alCerrarSesion,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 3. Fila de la lista del perfil.
class _Fila extends StatelessWidget {
  const _Fila({required this.icono, required this.titulo, required this.alPresionar, this.peligro = false});

  final String icono, titulo;
  final VoidCallback alPresionar;
  final bool peligro;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: alPresionar,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          BurbujaIcono(
            icono,
            tam: 36,
            fondo: peligro ? colorRojoFondo : colorVerdeSuave,
            color: peligro ? colorRojo : colorVerde,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              titulo,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: peligro ? colorRojo : colorVerdeOscuro,
              ),
            ),
          ),
          if (!peligro) const Icono('flecha', color: colorTextoSuave, tam: 18),
        ],
      ),
    ),
  );
}
