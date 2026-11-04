import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/animal.dart';
import '../models/granja.dart';
import '../models/miembro.dart';
import 'sesion.dart';

typedef Vinculo = ({Granja granja, RolMiembro rol});
typedef Resumen = ({int animales, int avisos, int miembros});

/// 1. Da un único acceso a los datos de las granjas en Supabase (Singleton).
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

  /// 3. Recuerda la granja con la que trabaja la persona en esta sesión.
  late Granja actual;
  RolMiembro rol = RolMiembro.trabajador;

  void seleccionar(Vinculo vinculo) {
    actual = vinculo.granja;
    rol = vinculo.rol;
  }

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

  /// 5. Cuenta los animales activos, los avisos de los próximos 7 días y los miembros de la granja actual.
  Future<Resumen> resumen() async {
    final limite = DateTime.now().add(const Duration(days: 7)).toIso8601String().substring(0, 10);
    final id = actual.id;
    final resultados = await Future.wait([
      _db.from('fichas_bovinas').select('id').eq('granja_id', id).isFilter('fecha_baja', null),
      _db
          .from('prevenciones')
          .select('id, fichas_bovinas!inner(granja_id, fecha_baja)')
          .eq('fichas_bovinas.granja_id', id)
          .isFilter('fichas_bovinas.fecha_baja', null)
          .eq('estado', 'pendiente')
          .lte('fecha_programada', limite),
      _db.from('vinculaciones').select('id').eq('granja_id', id).eq('activa', true),
      _db.from('invitaciones').select('id').eq('granja_id', id).eq('vigente', true).eq('aceptada', false),
    ]);
    return (
      animales: resultados[0].length,
      avisos: resultados[1].length,
      miembros: resultados[2].length + resultados[3].length,
    );
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

  /// 9. Trae los animales activos de la granja actual.
  Future<List<Animal>> animalesActivos() async {
    final filas = await _db
        .from('fichas_bovinas')
        .select('id, nombre, identificacion, etapa, raza')
        .eq('granja_id', actual.id)
        .isFilter('fecha_baja', null)
        .order('identificacion');
    return filas.map(Animal.fromMap).toList();
  }

  /// 10. Registra la baja del animal; devuelve null o el mensaje de error.
  Future<String?> darDeBaja(Animal animal, DateTime fecha, String motivo) async {
    try {
      await _db
          .from('fichas_bovinas')
          .update({'fecha_baja': fecha.toIso8601String().substring(0, 10), 'motivo_baja': motivo}).eq('id', animal.id);
      return null;
    } on PostgrestException {
      return 'No se pudo registrar la baja';
    } on Exception {
      return 'No se pudo conectar. Revisa tu internet';
    }
  }

  /// 11. Guarda la invitación y envía el correo; devuelve el error o si el correo salió.
  Future<({String? error, bool correoEnviado})> invitar(String correo, RolMiembro rol) async {
    final limpio = correo.trim().toLowerCase();
    try {
      final equipo = await miembros();
      if (equipo.any((m) => m.correo.toLowerCase() == limpio)) {
        return (error: 'Esa persona ya es miembro de la granja', correoEnviado: false);
      }
      final fila = await _db
          .from('invitaciones')
          .insert({'granja_id': actual.id, 'correo': limpio, 'rol': rol.name})
          .select('id')
          .single();
      return (error: null, correoEnviado: await enviarCorreo(fila['id'] as String));
    } on PostgrestException catch (e) {
      final mensaje = e.code == '23505'
          ? 'Esa persona ya tiene una invitación pendiente'
          : 'No se pudo registrar la invitación';
      return (error: mensaje, correoEnviado: false);
    } on Exception {
      return (error: 'No se pudo conectar. Revisa tu internet', correoEnviado: false);
    }
  }

  /// 12. Pide a la función de Supabase enviar el correo de una invitación con Mailgun.
  Future<bool> enviarCorreo(String invitacionId) async {
    try {
      await _db.functions.invoke('dynamic-action', body: {'invitacion_id': invitacionId});
      return true;
    } on Exception {
      return false;
    }
  }

  /// 13. Trae las invitaciones pendientes dirigidas al correo de la cuenta actual.
  Future<List<Invitacion>> misInvitaciones() async {
    final correo = (Sesion.instance.usuario ?? '').toLowerCase();
    final filas = await _db.from('invitaciones').select().eq('vigente', true).eq('aceptada', false);
    return filas.map(Invitacion.fromMap).where((i) => i.correo.toLowerCase() == correo).toList();
  }

  /// 14. Acepta una invitación y vincula la cuenta a su granja.
  Future<void> aceptarInvitacion(Invitacion invitacion) =>
      _db.rpc('aceptar_invitacion', params: {'p_invitacion': invitacion.id});
}
