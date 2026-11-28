import 'package:flutter/material.dart';

import '../../logic/administracion.dart';
import '../../logic/sesion.dart';
import '../../widgets/pantalla.dart';
import '../../widgets/vetlink.dart';

Future<bool> confirmarAdministracion(
  BuildContext context,
  String titulo,
  String texto,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (dialogo) => AlertDialog(
        title: Text(titulo),
        content: Text(texto),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogo, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogo, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    ) ??
    false;

class CuentaAdministrativaScreen extends StatefulWidget {
  const CuentaAdministrativaScreen({super.key, required this.cuentaId});
  final String cuentaId;
  @override
  State<CuentaAdministrativaScreen> createState() =>
      _CuentaAdministrativaScreenState();
}

class _CuentaAdministrativaScreenState
    extends State<CuentaAdministrativaScreen> {
  final _nombre = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _guardando = false;
  late Future<Map<String, dynamic>> _datos = _cargar();
  Future<Map<String, dynamic>> _cargar() async {
    final datos = await Administracion.instance.cuenta(widget.cuentaId);
    _nombre.text = (datos['cuenta'] as Map)['nombre'] as String? ?? '';
    return datos;
  }

  @override
  void dispose() {
    _nombre.dispose();
    super.dispose();
  }

  Future<void> _hacer(Future<void> Function() accion, String mensaje) async {
    if (_guardando) return;
    setState(() => _guardando = true);
    try {
      await accion();
      if (!mounted) return;
      avisar(context, mensaje);
      setState(() { _datos = _cargar(); });
    } on Exception catch (e) {
      if (mounted) {
        avisar(context, e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) => Pantalla(
    titulo: 'Detalle de cuenta',
    granja: 'Administración',
    children: [
      FutureBuilder(
        future: _datos,
        builder: (context, estado) {
          if (estado.hasError) {
            return TextButton(
              onPressed: () => setState(() { _datos = _cargar(); }),
              child: const Text('No se pudo cargar. Reintentar'),
            );
          }
          if (!estado.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final cuenta = estado.data!['cuenta'] as Map;
          final accesos = estado.data!['accesos'] as List;
          final activa = cuenta['activa'] == true;
          return Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CampoEtiquetado(
                  etiqueta: 'Nombre *',
                  child: TextFormField(
                    controller: _nombre,
                    enabled: !_guardando,
                    maxLength: 120,
                    decoration: decoracionCampo(),
                    validator: requerido,
                  ),
                ),
                const Text('Correo de acceso'),
                Text('${cuenta['correo']}'),
                const SizedBox(height: 16),
                Text('Estado: ${activa ? 'Activa' : 'Desactivada'}'),
                const SizedBox(height: 16),
                const Text(
                  'Accesos por granja',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                if (accesos.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('Sin granjas vinculadas.'),
                  ),
                for (final acceso in accesos)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Tarjeta(
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${acceso['granja']}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '${acceso['rol']} · ${acceso['activa'] == true ? 'Activo' : 'Suspendido'}',
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: _guardando
                                ? null
                                : () async {
                                    if (!await confirmarAdministracion(
                                      context,
                                      'Cambiar acceso',
                                      '¿Cambiar el acceso a ${acceso['granja']}? Sus registros se conservarán.',
                                    )) {
                                      return;
                                    }
                                    await _hacer(
                                      () =>
                                          Administracion.instance.cambiarAcceso(
                                            acceso['id'] as String,
                                            acceso['activa'] != true,
                                          ),
                                      'Acceso actualizado',
                                    );
                                  },
                            child: Text(
                              acceso['activa'] == true
                                  ? 'Desactivar'
                                  : 'Restablecer',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                BotonPrincipal(
                  texto: _guardando ? 'Guardando...' : 'Guardar cambios',
                  alPresionar: _guardando
                      ? null
                      : () {
                          if (_form.currentState!.validate()) {
                            _hacer(
                              () => Administracion.instance.guardarCuenta(
                                widget.cuentaId,
                                _nombre.text,
                                activa,
                              ),
                              'Cuenta actualizada',
                            );
                          }
                        },
                ),
                BotonSecundario(
                  texto: 'Enviar recuperación de acceso',
                  alPresionar: _guardando || !activa
                      ? null
                      : () async {
                          if (!await confirmarAdministracion(
                            context,
                            'Recuperar acceso',
                            'Se enviará un enlace al correo ${cuenta['correo']}.',
                          )) {
                            return;
                          }
                          await _hacer(
                            () => Administracion.instance.recuperar(
                              widget.cuentaId,
                            ),
                            'Revisá el correo de la cuenta',
                          );
                        },
                ),
                BotonPrincipal(
                  texto: activa ? 'Desactivar cuenta' : 'Activar cuenta',
                  color: activa ? colorRojo : colorVerde,
                  alPresionar:
                      _guardando ||
                          (activa && widget.cuentaId == Sesion.instance.id)
                      ? null
                      : () async {
                          if (!await confirmarAdministracion(
                            context,
                            activa ? 'Desactivar cuenta' : 'Activar cuenta',
                            'Sus registros y su autoría se conservarán.',
                          )) {
                            return;
                          }
                          await _hacer(
                            () => Administracion.instance.guardarCuenta(
                              widget.cuentaId,
                              cuenta['nombre'] as String,
                              !activa,
                            ),
                            'Estado de cuenta actualizado',
                          );
                        },
                ),
              ],
            ),
          );
        },
      ),
    ],
  );
}
