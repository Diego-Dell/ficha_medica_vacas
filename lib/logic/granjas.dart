import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/granja.dart';
import '../models/miembro.dart';
import 'sesion.dart';

typedef Vinculo = ({Granja granja, RolMiembro rol});
typedef Resumen = ({int miembros, int pendientes});

/// 1. Da un único acceso a los datos de las granjas (Singleton) y esconde las consultas de Supabase detrás de métodos simples (Facade).
class Granjas {
  Granjas._();
  static final instance = Granjas._();

  SupabaseClient? _cliente;

  @visibleForTesting
  set cliente(SupabaseClient valor) => _cliente = valor;

  /// 2. Conecta el acceso a los datos al abrir la app.
  void conectar(SupabaseClient valor) => _cliente = valor;

  SupabaseClient get _db {
    final cliente = _cliente;
    if (cliente == null) throw Exception('La app no está configurada');
    return cliente;
  }

  /// 3. Recuerda la granja con la que trabaja la persona en esta sesión y su rol en ella.
  Granja? _actual;
  Granja get actual => _actual!;
  RolMiembro rol = RolMiembro.trabajador;

  void seleccionar(Vinculo vinculo) {
    _actual = vinculo.granja;
    rol = vinculo.rol;
  }

  bool esActual(Granja granja) => _actual?.id == granja.id;

  /// Consulta la función existente: solo reconoce administradores con cuenta activa.
  Future<bool> esAdministrador() async => await _db.rpc('es_administrador') == true;

  /// 4. Trae las granjas de la cuenta actual con su rol en cada una.
  Future<List<Vinculo>> misVinculos() async {
    final filas = await _db
        .from('vinculaciones')
        .select('rol, granjas(*)')
        .eq('cuenta_id', Sesion.instance.id ?? '')
        .eq('activa', true);
    return [
      for (final fila in filas)
        (
          granja: Granja.fromMap(fila['granjas'] as Map<String, dynamic>, dueno: Sesion.instance.nombre),
          rol: RolMiembro.values.byName(fila['rol'] as String),
        ),
    ];
  }

  /// 5. Cuenta los miembros activos y las invitaciones pendientes de la granja actual.
  Future<Resumen> resumen() async {
    final (miembros, pendientes) = await (this.miembros(), invitaciones()).wait;
    return (miembros: miembros.length, pendientes: pendientes.length);
  }

  /// 6. Trae los miembros activos de la granja actual.
  Future<List<Miembro>> miembros() async {
    final filas = await _db
        .from('vinculaciones')
        .select('rol, cuentas(nombre, identificador)')
        .eq('granja_id', actual.id)
        .eq('activa', true);
    return filas.map(Miembro.fromMap).toList();
  }

  /// 7. Trae las invitaciones pendientes de la granja actual.
  Future<List<Invitacion>> invitaciones() async {
    final filas = await _db
        .from('invitaciones')
        .select()
        .eq('granja_id', actual.id)
        .eq('vigente', true)
        .eq('aceptada', false)
        .order('enviada_en');
    return filas.map(Invitacion.fromMap).toList();
  }

  /// 8. Registra otra granja con la cuenta actual; devuelve null o el mensaje de error.
  Future<String?> registrarGranja(Granja granja) async {
    try {
      await _db.rpc('registrar_granja', params: {
        'p_nombre': granja.nombre,
        'p_hectareas': granja.superficie,
        'p_runsa': granja.runsa,
        'p_documentos': granja.documento,
      });
      return null;
    } on PostgrestException {
      return 'No se pudo registrar la granja';
    } on Exception {
      return 'No se pudo conectar. Revisa tu internet';
    }
  }

  /// 9. Guarda la invitación y envía el correo; devuelve el error de la invitación o el motivo por el que no salió el correo.
  Future<({String? error, String? errorCorreo})> invitar(String correo, RolMiembro rol) async {
    final limpio = correo.trim().toLowerCase();
    try {
      final equipo = await miembros();
      if (equipo.any((m) => m.correo.toLowerCase() == limpio)) {
        return (error: 'Esa persona ya es miembro de la granja', errorCorreo: null);
      }
      final fila = await _db
          .from('invitaciones')
          .insert({'granja_id': actual.id, 'correo': limpio, 'rol': rol.name})
          .select('id')
          .single();
      return (error: null, errorCorreo: await enviarCorreo(fila['id'] as String));
    } on PostgrestException catch (e) {
      final mensaje = e.code == '23505'
          ? 'Esa persona ya tiene una invitación pendiente'
          : 'No se pudo registrar la invitación';
      return (error: mensaje, errorCorreo: null);
    } on Exception {
      return (error: 'No se pudo conectar. Revisa tu internet', errorCorreo: null);
    }
  }

  /// 10. Pide a la función de Supabase enviar el correo con Mailgun; devuelve null o el motivo que informa la función.
  Future<String?> enviarCorreo(String invitacionId) async {
    try {
      await _db.functions.invoke('dynamic-action', body: {'invitacion_id': invitacionId});
      return null;
    } on FunctionsFetchException {
      return 'No se pudo conectar. Revisa tu internet';
    } on FunctionException catch (e) {
      final detalle = e.details;
      return detalle is Map && detalle['error'] is String ? detalle['error'] as String : 'No se pudo enviar el correo';
    } on Exception {
      return 'No se pudo enviar el correo';
    }
  }

  /// 11. Trae las invitaciones pendientes dirigidas al correo de la cuenta actual.
  Future<List<Invitacion>> misInvitaciones() async {
    final correo = (Sesion.instance.usuario ?? '').toLowerCase();
    final filas = await _db.from('invitaciones').select().eq('vigente', true).eq('aceptada', false);
    return filas.map(Invitacion.fromMap).where((i) => i.correo.toLowerCase() == correo).toList();
  }

  /// 12. Acepta una invitación y vincula la cuenta a su granja; devuelve null o el mensaje de error.
  Future<String?> aceptarInvitacion(Invitacion invitacion) async {
    try {
      await _db.rpc('aceptar_invitacion', params: {'p_invitacion': invitacion.id});
      return null;
    } on PostgrestException {
      return 'La invitación ya no está vigente';
    } on Exception {
      return 'No se pudo aceptar la invitación. Revisa tu internet';
    }
  }

  /// 13. Trae las granjas que esperan la confirmación del administrador técnico.
  Future<List<Granja>> porConfirmar() async {
    final filas = await _db.from('granjas').select().eq('confirmada', false).order('nombre');
    return [for (final fila in filas) Granja.fromMap(fila, dueno: '')];
  }

  /// 14. Confirma una granja en revisión; devuelve null o el mensaje de error.
  Future<String?> confirmar(Granja granja) async {
    try {
      await _db.rpc('confirmar_granja', params: {'p_granja': granja.id});
      return null;
    } on PostgrestException {
      return 'No se pudo confirmar la granja';
    } on Exception {
      return 'No se pudo conectar. Revisa tu internet';
    }
  }
}
