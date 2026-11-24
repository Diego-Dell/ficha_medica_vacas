import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/granja.dart';
import '../models/miembro.dart';
import 'sesion.dart';
import 'documentos.dart';

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

  void seleccionarAdministracion(Granja granja) {
    if (!sesionAdministradora || !granja.confirmada || granja.rechazada) {
      throw StateError(
        'Se necesita una granja confirmada y una cuenta administradora',
      );
    }
    _actual = granja;
  }

  bool esActual(Granja granja) => _actual?.id == granja.id;

  /// Consulta la función existente: solo reconoce administradores con cuenta activa.
  String? _cuentaAdministradora;
  bool get sesionAdministradora =>
      Sesion.instance.id != null && _cuentaAdministradora == Sesion.instance.id;

  Future<bool> esAdministrador() async {
    final administrador = await _db.rpc('es_administrador') == true;
    _cuentaAdministradora = administrador ? Sesion.instance.id : null;
    return administrador;
  }

  /// Supabase aplica los permisos del administrador; no depende de sus vínculos como dueño.
  Future<List<Granja>> todas() async {
    final filas = await _db.from('granjas').select().order('nombre');
    return [for (final fila in filas) Granja.fromMap(fila, dueno: '')];
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
          granja: Granja.fromMap(
            fila['granjas'] as Map<String, dynamic>,
            dueno: Sesion.instance.nombre,
          ),
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
        .select('cuenta_id, rol, cuentas(nombre, identificador)')
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

  /// Quita únicamente el vínculo con la granja; Supabase comprueba el permiso del dueño.
  Future<String?> expulsar(Miembro miembro) async {
    if (rol != RolMiembro.dueno ||
        miembro.rol == RolMiembro.dueno ||
        miembro.cuentaId.isEmpty ||
        miembro.cuentaId == Sesion.instance.id) {
      return 'Solo el dueño puede expulsar a un veterinario o trabajador';
    }
    try {
      await _db.rpc(
        'expulsar_miembro',
        params: {'p_granja': actual.id, 'p_cuenta': miembro.cuentaId},
      );
      return null;
    } on PostgrestException {
      return 'No se pudo expulsar al miembro. Actualizá el equipo e intentá de nuevo';
    } on Exception {
      return 'No se pudo conectar. Revisa tu internet';
    }
  }

  /// 8. Registra otra granja con la cuenta actual; devuelve null o el mensaje de error.
  Future<String?> registrarGranja(Granja granja) async {
    try {
      final archivo = await Documentos.local(granja.documento);
      if (!await archivo.exists()) {
        return 'Adjuntá el PDF para completar el registro';
      }
      final bytes = await archivo.readAsBytes();
      final tipo = Documentos.tipo(Documentos.nombre(granja.documento), bytes);
      final clave = granja.documento.split('/')[1];
      final id =
          '${clave.substring(0, 8)}-${clave.substring(8, 12)}-${clave.substring(12, 16)}-${clave.substring(16, 20)}-${clave.substring(20)}';
      final ruta =
          '${Sesion.instance.id}/$id/${Documentos.nombre(granja.documento)}';
      // Primero el PDF; si falla, no se crea ninguna granja.
      await _db.storage
          .from(Documentos.bucket)
          .uploadBinary(
            ruta,
            bytes,
            fileOptions: FileOptions(contentType: tipo, upsert: true),
          );
      await _db.rpc(
        'registrar_granja',
        params: {
          'p_nombre': granja.nombre,
          'p_hectareas': granja.superficie,
          'p_runsa': granja.runsa,
          'p_documentos': 'storage/$ruta',
        },
      );
      try {
        await archivo.delete();
      } on Exception {
        /* El PDF ya está guardado. */
      }
      return null;
    } on FormatException catch (e) {
      return e.message;
    } on PostgrestException {
      return 'No se pudo registrar la granja';
    } on Exception {
      return 'No se completó el registro. Revisá la conexión y reintentá subir el PDF';
    }
  }

  /// 9. Guarda la invitación y envía el correo; devuelve el error de la invitación o el motivo por el que no salió el correo.
  Future<({String? error, String? errorCorreo})> invitar(
    String correo,
    RolMiembro rol,
  ) async {
    final limpio = correo.trim().toLowerCase();
    try {
      final equipo = await miembros();
      if (equipo.any((m) => m.correo.toLowerCase() == limpio)) {
        return (
          error: 'Esa persona ya es miembro de la granja',
          errorCorreo: null,
        );
      }
      final fila = await _db
          .from('invitaciones')
          .insert({'granja_id': actual.id, 'correo': limpio, 'rol': rol.name})
          .select('id')
          .single();
      return (
        error: null,
        errorCorreo: await enviarCorreo(fila['id'] as String),
      );
    } on PostgrestException catch (e) {
      final mensaje = e.code == '23505'
          ? 'Esa persona ya tiene una invitación pendiente'
          : 'No se pudo registrar la invitación';
      return (error: mensaje, errorCorreo: null);
    } on Exception {
      return (
        error: 'No se pudo conectar. Revisa tu internet',
        errorCorreo: null,
      );
    }
  }

  /// 10. Pide a la función de Supabase enviar el correo con Mailgun; devuelve null o el motivo que informa la función.
  Future<String?> enviarCorreo(String invitacionId) async {
    try {
      await _db.functions.invoke(
        'dynamic-action',
        body: {'invitacion_id': invitacionId},
      );
      return null;
    } on FunctionsFetchException {
      return 'No se pudo conectar. Revisa tu internet';
    } on FunctionException catch (e) {
      final detalle = e.details;
      return detalle is Map && detalle['error'] is String
          ? detalle['error'] as String
          : 'No se pudo enviar el correo';
    } on Exception {
      return 'No se pudo enviar el correo';
    }
  }

  /// 11. Trae las invitaciones pendientes dirigidas al correo de la cuenta actual.
  Future<List<Invitacion>> misInvitaciones() async {
    final correo = (Sesion.instance.usuario ?? '').toLowerCase();
    final filas = (await _db.rpc('mis_invitaciones') as List)
        .cast<Map<String, dynamic>>();
    return filas
        .map(Invitacion.fromMap)
        .where((i) => i.correo.toLowerCase() == correo)
        .toList();
  }

  /// 12. Acepta una invitación y vincula la cuenta a su granja; devuelve null o el mensaje de error.
  Future<String?> aceptarInvitacion(Invitacion invitacion) async {
    try {
      await _db.rpc(
        'aceptar_invitacion',
        params: {'p_invitacion': invitacion.id},
      );
      return null;
    } on PostgrestException {
      return 'La invitación ya no está vigente';
    } on Exception {
      return 'No se pudo aceptar la invitación. Revisa tu internet';
    }
  }

  /// 13. Trae las granjas que esperan la confirmación del administrador técnico, con el dueño de cada una.
  Future<List<Granja>> porConfirmar() async {
    final filas = await _db
        .from('granjas')
        .select('*, vinculaciones(rol, cuentas(nombre, identificador))')
        .eq('confirmada', false)
        .order('nombre');
    return [
      for (final fila in filas)
        if (fila['motivo_rechazo'] == null)
          Granja.fromMap(fila, dueno: _duenoDe(fila)),
    ];
  }

  /// 13.1. Escribe el nombre y el correo del dueño; si la base no lo muestra, lo avisa.
  String _duenoDe(Map<String, dynamic> fila) {
    final vinculos = (fila['vinculaciones'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    final cuenta =
        vinculos.where((v) => v['rol'] == 'dueno').firstOrNull?['cuentas']
            as Map<String, dynamic>?;
    if (cuenta == null) return 'No disponible';
    final correo = cuenta['identificador'] as String;
    final nombre = cuenta['nombre'] as String?;
    return nombre == null ? correo : '$nombre · $correo';
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

  /// Conserva la solicitud y el motivo; solo el administrador puede rechazarla.
  Future<String?> rechazar(Granja granja, String motivo) async {
    if (motivo.trim().isEmpty) return 'Escribí el motivo del rechazo';
    try {
      await _db.rpc(
        'rechazar_granja',
        params: {'p_granja': granja.id, 'p_motivo': motivo.trim()},
      );
      return null;
    } on PostgrestException {
      return 'No se pudo rechazar la solicitud. Actualizá las solicitudes e intentá de nuevo';
    } on Exception {
      return 'No se pudo conectar. Revisa tu internet';
    }
  }

  /// Sube el archivo privado y después guarda su ruta en la solicitud.
  Future<String?> subirDocumento(Granja granja, String pendiente) async {
    try {
      final archivo = await Documentos.local(pendiente);
      if (!await archivo.exists()) {
        return 'Seleccioná el documento desde este teléfono para completar la solicitud';
      }
      final bytes = await archivo.readAsBytes();
      final tipo = Documentos.tipo(Documentos.nombre(pendiente), bytes);
      final ruta =
          '${Sesion.instance.id}/${granja.id}/${pendiente.substring(10)}';
      await _db.storage
          .from(Documentos.bucket)
          .uploadBinary(
            ruta,
            bytes,
            fileOptions: FileOptions(contentType: tipo, upsert: true),
          );
      await _db.rpc(
        'adjuntar_documento_granja',
        params: {'p_granja': granja.id, 'p_ruta': ruta},
      );
      try {
        await archivo.delete();
      } on Exception {
        /* La copia remota ya está guardada. */
      }
      return null;
    } on Exception {
      return 'La granja está registrada, pero falta subir el documento. Reintentá desde Granja en revisión';
    }
  }

  Future<String?> subirDocumentosPendientes() async {
    String? pendiente;
    try {
      for (final vinculo in await misVinculos()) {
        if (vinculo.rol != RolMiembro.dueno ||
            vinculo.granja.confirmada ||
            vinculo.granja.rechazada ||
            !vinculo.granja.documento.startsWith('pendiente/')) {
          continue;
        }
        final error = await subirDocumento(
          vinculo.granja,
          vinculo.granja.documento,
        );
        pendiente ??= error;
      }
      return pendiente;
    } on Exception {
      return 'No se pudo subir la documentación. Podés reintentar desde Granja en revisión';
    }
  }

  Future<String> enlaceDocumento(Granja granja) {
    if (!Documentos.subido(granja.documento)) {
      throw const FormatException('El dueño todavía no subió el archivo');
    }
    return _db.storage
        .from(Documentos.bucket)
        .createSignedUrl(granja.documento.substring(8), 300);
  }

  /// 12. Actualiza el RUNSA de la granja actual; solo el dueño puede hacerlo.
  Future<String?> actualizarRunsa(String runsa) async {
    final limpio = runsa.trim().toUpperCase();
    try {
      final filas = await _db
          .from('granjas')
          .update({'runsa': limpio})
          .eq('id', actual.id)
          .select('id');
      if (filas.isEmpty) return 'Tu rol no permite este cambio';
      _actual = actual.conRunsa(limpio);
      return null;
    } on PostgrestException {
      return 'No se pudo guardar el RUNSA';
    } on Exception {
      return 'No se pudo conectar. Revisa tu internet';
    }
  }
}
