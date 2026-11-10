import '../models/animal.dart';
import '../models/granja.dart';
import '../models/miembro.dart';
import 'api.dart';
import 'sesion.dart';

typedef Vinculo = ({Granja granja, RolMiembro rol});
typedef Resumen = ({int animales, int avisos, int miembros});

<<<<<<< HEAD
/// 1. Da un único acceso a los datos de las granjas (Singleton) y esconde las consultas de Supabase detrás de métodos simples (Facade).
=======
>>>>>>> bb40139 (feat: integrar backend propio y flujos de acceso VetLink)
class Granjas {
  Granjas._();
  static final instance = Granjas._();
  late Granja actual;
  RolMiembro rol = RolMiembro.trabajador;

  Api get cliente => Sesion.instance.api;

  void seleccionar(Vinculo vinculo) {
    actual = vinculo.granja;
    rol = vinculo.rol;
  }

  Future<bool> esAdministrador() async {
    final resultado =
        await cliente.pedir('/es_administrador') as Map<String, dynamic>;
    return resultado['administrador'] == true;
  }

  Future<List<Granja>> granjasPendientes() async {
    final filas = await cliente.pedir(
      '/administracion/granjas-pendientes',
    ) as List<dynamic>;
    return filas.cast<Map<String, dynamic>>().map((fila) {
      return Granja.fromMap(
        fila,
        dueno: fila['dueno'] as String? ?? 'Dueño no disponible',
      );
    }).toList();
  }

  Future<String?> confirmarSolicitudGranja(String id) async {
    try {
      await cliente.pedir(
        '/administracion/granjas/$id/confirmar',
        metodo: 'POST',
        datos: const {},
      );
      return null;
    } on ApiException catch (error) {
      return error.mensaje;
    } catch (_) {
      return 'No se pudo conectar al servidor. Revisa tu internet';
    }
  }

  Future<List<Vinculo>> misVinculos() async {
    final filas = await cliente.pedir('/vinculaciones') as List<dynamic>;
    return [
      for (final fila in filas.cast<Map<String, dynamic>>())
        (
          granja: Granja.fromMap(
            fila['granjas'] as Map<String, dynamic>,
            dueno: Sesion.instance.nombre,
          ),
          rol: RolMiembro.values.byName(fila['rol'] as String),
        ),
    ];
  }

  Future<Resumen> resumen() async {
    final fila = await cliente.pedir(
      '/granjas/${actual.id}/resumen',
    ) as Map<String, dynamic>;
    return (
      animales: (fila['animales'] as num).toInt(),
      avisos: (fila['avisos'] as num).toInt(),
      miembros: (fila['miembros'] as num).toInt(),
    );
  }

  Future<List<Miembro>> miembros() async {
    final filas =
        await cliente.pedir('/granjas/${actual.id}/miembros') as List<dynamic>;
    return filas.cast<Map<String, dynamic>>().map(Miembro.fromMap).toList();
  }

  Future<List<Invitacion>> invitaciones() async {
    final filas = await cliente.pedir(
      '/granjas/${actual.id}/invitaciones',
    ) as List<dynamic>;
    return filas.cast<Map<String, dynamic>>().map(Invitacion.fromMap).toList();
  }

  Future<String?> registrarGranja(Granja granja) async {
    try {
      await cliente.pedir(
        '/registrar_granja',
        metodo: 'POST',
        datos: {
          'p_nombre': granja.nombre,
          'p_hectareas': granja.superficie,
          'p_runsa': granja.runsa,
          'p_documentos': granja.documento,
        },
      );
      return null;
    } on ApiException catch (error) {
      return error.mensaje;
    } catch (_) {
      return 'No se pudo conectar al servidor. Revisa tu internet';
    }
  }

  Future<List<Animal>> animalesActivos() async {
    final filas = await cliente.pedir(
      '/granjas/${actual.id}/fichas_bovinas',
    ) as List<dynamic>;
    return filas.cast<Map<String, dynamic>>().map(Animal.fromMap).toList();
  }

  Future<String?> darDeBaja(
    Animal animal,
    DateTime fecha,
    String motivo,
  ) async {
    try {
      await cliente.pedir(
        '/granjas/${actual.id}/fichas_bovinas/${animal.id}/baja',
        metodo: 'POST',
        datos: {
          'fecha_baja': fecha.toIso8601String().substring(0, 10),
          'motivo_baja': motivo.trim(),
        },
      );
      return null;
    } on ApiException catch (error) {
      return error.mensaje;
    } catch (_) {
      return 'No se pudo conectar al servidor. Revisa tu internet';
    }
  }

  Future<({String? error, bool correoEnviado, String? errorCorreo})> invitar(
    String correo,
    RolMiembro rol,
  ) async {
    final destino = correo.trim().toLowerCase();
    if (destino == Sesion.instance.usuario?.toLowerCase()) {
      return (
        error: 'No puedes invitar tu propia cuenta a esta granja.',
        correoEnviado: false,
        errorCorreo: null,
      );
    }
    try {
      final fila = await cliente.pedir(
        '/invitaciones',
        metodo: 'POST',
        datos: {'granja_id': actual.id, 'correo': destino, 'rol': rol.name},
      ) as Map<String, dynamic>;
      final errorCorreo = await enviarCorreo(fila['id'] as String);
      return (
        error: null,
        correoEnviado: errorCorreo == null,
        errorCorreo: errorCorreo,
      );
    } on ApiException catch (error) {
      return (error: error.mensaje, correoEnviado: false, errorCorreo: null);
    } catch (_) {
      return (
        error: 'No se pudo conectar al servidor. Revisa tu internet',
        correoEnviado: false,
        errorCorreo: null,
      );
    }
  }

  Future<String?> enviarCorreo(String invitacionId) async {
    try {
      await cliente.pedir(
        '/dynamic-action',
        metodo: 'POST',
        datos: {'invitacion_id': invitacionId},
      );
      return null;
    } on ApiException catch (error) {
      return error.mensaje;
    } catch (_) {
      return 'No se pudo conectar a Mailgun. La invitación quedó guardada.';
    }
  }

  Future<List<Invitacion>> misInvitaciones() async {
    final filas = await cliente.pedir('/invitaciones') as List<dynamic>;
    return filas.cast<Map<String, dynamic>>().map(Invitacion.fromMap).toList();
  }

  Future<void> aceptarInvitacion(Invitacion invitacion) async {
    await cliente.pedir(
      '/aceptar_invitacion',
      metodo: 'POST',
      datos: {'p_invitacion': invitacion.id},
    );
  }
}
