import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../logic/clinica.dart';
import '../logic/fichas.dart';
import '../logic/granjas.dart';
import '../logic/tratamientos.dart';
import '../models/granja.dart';
import '../models/miembro.dart';
import '../models/registro_clinico.dart';

// Solo se importa desde main_vista_previa.dart. Todos los pedidos se resuelven en memoria.
class DatosVistaPrevia {
  static const granja = Granja(
    id: 'demo-granja',
    nombre: 'Los Pinos · Demo',
    dueno: 'Equipo de prueba',
    superficie: 18,
    runsa: 'DEMO',
    documento: 'Demo.pdf',
    confirmada: true,
  );
  final List<Map<String, dynamic>> animales = [
    {
      'id': 'demo-animal',
      'granja_id': granja.id,
      'identificacion': '0842',
      'nombre': 'Lucera',
      'etapa': 'vaca',
      'raza': 'Holstein',
    },
    {
      'id': 'demo-otro',
      'granja_id': granja.id,
      'identificacion': '0900',
      'nombre': 'Mora',
      'etapa': 'vaquilla',
    },
  ];
  final List<Map<String, dynamic>> tratamientos = [], prevenciones = [];
  late final List<Map<String, dynamic>> atenciones = [
    {
      'id': 'demo-atencion',
      'fichaBovinaId': 'demo-animal',
      'cuentaVeterinarioId': 'demo-cuenta',
      'fecha': DateTime.now()
          .subtract(const Duration(days: 2))
          .toUtc()
          .toIso8601String(),
      'tipo': 'Diagnostico',
      'detalle': 'Atención de ejemplo para probar indicaciones.',
      'anulado': false,
    },
    {
      'id': 'demo-atencion-otra',
      'fichaBovinaId': 'demo-otro',
      'cuentaVeterinarioId': 'demo-cuenta',
      'fecha': DateTime.now()
          .subtract(const Duration(days: 1))
          .toUtc()
          .toIso8601String(),
      'tipo': 'Control',
      'detalle': 'Control de ejemplo.',
      'anulado': false,
    },
  ];
  int _numero = 0;
  String _id() => 'demo-${++_numero}';

  Future<void> inicializar() async {
    final cliente = MockClient(_responder);
    // ignore: invalid_use_of_visible_for_testing_member
    Fichas.instance.usarApi(
      'https://vista-previa.invalid',
      cliente,
    );
    // ignore: invalid_use_of_visible_for_testing_member
    Clinica.instance.usarApi(
      'https://vista-previa.invalid',
      cliente,
      token: () => 'demo',
      autor: () => 'demo-cuenta',
    );
    // También la vista previa atraviesa el cliente HTTP del módulo; no usa
    // consultas PostgREST para Tratamientos ni Prevención.
    Tratamientos.instance.usarApi(
      'https://vista-previa.invalid',
      cliente,
      token: () => 'demo',
    );
    seleccionar(RolMiembro.veterinario);
    final hoy = fechaApi(DateTime.now());
    tratamientos.add({
      'id': _id(),
      'ficha_id': 'demo-animal',
      'atencion_id': 'demo-atencion',
      'prescrito_por': 'demo-cuenta',
      'medicamento': 'Medicamento de ejemplo',
      'dosis': 2.5,
      'unidad': 'ml',
      'via': 'Vía de ejemplo',
      'frecuencia': '12 h',
      'inicio': hoy,
      'duracion': '3 días',
      'retiro': 'Retiro de ejemplo; usar solo datos de prueba.',
      'anulado': false,
      'version': 1,
    });
    prevenciones.add({
      'id': _id(),
      'ficha_id': 'demo-animal',
      'programado_por': 'demo-cuenta',
      'tipo': 'control',
      'nombre': 'Control de seguimiento',
      'fecha_programada': hoy,
      'estado': 'pendiente',
      'version': 1,
    });
  }

  void seleccionar(RolMiembro rol) =>
      Granjas.instance.seleccionar((granja: granja, rol: rol));

  Future<http.Response> _responder(http.Request pedido) async {
    final ruta = pedido.url.path;
    final datos = pedido.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(pedido.body) as Map<String, dynamic>;
    Object? respuesta = [];
    if (ruta.contains('/auth/v1/token')) {
      String parte(Object o) =>
          base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
      final vence =
          DateTime.now()
              .add(const Duration(hours: 12))
              .millisecondsSinceEpoch ~/
          1000;
      respuesta = {
        'access_token':
            '${parte({'alg': 'HS256'})}.${parte({'sub': 'demo-cuenta', 'exp': vence})}.demo',
        'token_type': 'bearer',
        'expires_in': 43200,
        'expires_at': vence,
        'refresh_token': 'demo',
        'user': {
          'id': 'demo-cuenta',
          'aud': 'authenticated',
          'email': 'demo@example.invalid',
          'created_at': '2026-01-01T00:00:00Z',
          'app_metadata': {},
          'user_metadata': {'nombre': 'Equipo de prueba'},
        },
      };
    } else if (ruta == '/api/tratamientos' && pedido.method == 'GET') {
      final ficha = pedido.url.queryParameters['fichaBovinaId'];
      respuesta = tratamientos
          .where((t) => ficha == null || t['ficha_id'] == ficha)
          .map(_tratamientoApi)
          .toList();
    } else if (ruta == '/api/tratamientos' && pedido.method == 'POST') {
      final id = _id();
      final nuevo = {
        'id': id,
        'ficha_id': datos['fichaBovinaId'],
        'atencion_id': datos['atencionClinicaId'],
        'prescrito_por': 'demo-cuenta',
        'medicamento': datos['medicamento'],
        'dosis': datos['dosis'],
        'unidad': datos['unidad'],
        'via': datos['via'],
        'frecuencia': datos['frecuencia'],
        'inicio': datos['inicio'],
        'duracion': datos['duracion'],
        'retiro': datos['retiro'],
        'anulado': false,
        'version': 1,
      };
      tratamientos.add(nuevo);
      respuesta = _tratamientoApi(nuevo);
    } else if (ruta.startsWith('/api/tratamientos/') &&
        ruta.endsWith('/reemplazar') &&
        pedido.method == 'POST') {
      final anteriorId = pedido.url.pathSegments[2];
      final anterior = tratamientos.firstWhere((t) => t['id'] == anteriorId);
      anterior.addAll({
        'fecha_fin': datos['fechaFinAnterior'],
        'motivo_fin': datos['motivoFinAnterior'],
        'version': (anterior['version'] as int) + 1,
      });
      final nuevo = {
        'id': _id(),
        'ficha_id': anterior['ficha_id'],
        'atencion_id': anterior['atencion_id'],
        'prescrito_por': 'demo-cuenta',
        'medicamento': datos['medicamento'],
        'dosis': datos['dosis'],
        'unidad': datos['unidad'],
        'via': datos['via'],
        'frecuencia': datos['frecuencia'],
        'inicio': datos['inicio'],
        'duracion': datos['duracion'],
        'retiro': datos['retiro'],
        'anterior_id': anteriorId,
        'anulado': false,
        'version': 1,
      };
      tratamientos.add(nuevo);
      respuesta = _tratamientoApi(nuevo);
    } else if (ruta.startsWith('/api/tratamientos/') &&
        ruta.endsWith('/finalizar') &&
        pedido.method == 'POST') {
      final t = tratamientos.firstWhere(
        (t) => t['id'] == pedido.url.pathSegments[2],
      );
      t.addAll({
        'fecha_fin': datos['fechaFin'],
        'motivo_fin': datos['motivoFin'],
        'version': (t['version'] as int) + 1,
      });
      respuesta = null;
    } else if (ruta == '/api/prevenciones' && pedido.method == 'GET') {
      final ficha = pedido.url.queryParameters['fichaBovinaId'];
      respuesta = prevenciones
          .where((p) => ficha == null || p['ficha_id'] == ficha)
          .map(_prevencionApi)
          .toList();
    } else if (ruta == '/api/prevenciones' && pedido.method == 'POST') {
      final nueva = {
        'id': _id(),
        'ficha_id': datos['fichaBovinaId'],
        'programado_por': 'demo-cuenta',
        'tipo': (datos['tipo'] as String).toLowerCase(),
        'nombre': datos['nombre'],
        'fecha_programada': datos['fechaProgramada'],
        'estado': 'pendiente',
        'version': 1,
      };
      prevenciones.add(nueva);
      respuesta = _prevencionApi(nueva);
    } else if (ruta.startsWith('/api/prevenciones/') &&
        ruta.endsWith('/completar-control') &&
        pedido.method == 'POST') {
      final p = prevenciones.firstWhere(
        (p) => p['id'] == pedido.url.pathSegments[2],
      );
      p.addAll({
        'estado': 'realizada',
        'fecha_realizacion': datos['fechaRealizacion'],
        'version': (p['version'] as int) + 1,
      });
      respuesta = null;
    } else if (ruta.contains('/rpc/')) {
      // Compatibilidad con otros módulos de la vista previa: este módulo no
      // llega aquí, porque usa las rutas /api/* de arriba.
      final funcion = pedido.url.pathSegments.last;
      if (funcion == 'guardar_indicacion_tratamiento') {
        if (datos['p_anterior'] != null) {
          final anterior = tratamientos.firstWhere(
            (t) => t['id'] == datos['p_anterior'],
          );
          anterior.addAll({
            'fecha_fin': datos['p_fecha_fin'],
            'motivo_fin': datos['p_motivo'],
            'version': (anterior['version'] as int) + 1,
          });
        }
        final id = _id();
        tratamientos.add({
          'id': id,
          'ficha_id': datos['p_ficha'],
          'atencion_id': datos['p_atencion'],
          'prescrito_por': 'demo-cuenta',
          ...datos['p_datos'] as Map<String, dynamic>,
          'anterior_id': datos['p_anterior'],
          'anulado': false,
          'version': 1,
        });
        respuesta = id;
      } else if (funcion == 'finalizar_indicacion_tratamiento') {
        final t = tratamientos.firstWhere(
          (t) => t['id'] == datos['p_tratamiento'],
        );
        t.addAll({
          'fecha_fin': datos['p_fecha_fin'],
          'motivo_fin': datos['p_motivo'],
          'version': (t['version'] as int) + 1,
        });
        respuesta = null;
      } else if (funcion == 'programar_prevencion') {
        final id = _id();
        prevenciones.add({
          'id': id,
          'ficha_id': datos['p_ficha'],
          'programado_por': 'demo-cuenta',
          'tipo': (datos['p_tipo'] as String).toLowerCase(),
          'nombre': datos['p_nombre'],
          'fecha_programada': datos['p_fecha'],
          'estado': 'pendiente',
          'version': 1,
        });
        respuesta = id;
      } else if (funcion == 'completar_control_preventivo') {
        final p = prevenciones.firstWhere(
          (p) => p['id'] == datos['p_prevencion'],
        );
        p.addAll({
          'estado': 'realizada',
          'fecha_realizacion': datos['p_fecha'],
          'version': (p['version'] as int) + 1,
        });
        respuesta = null;
      }
    } else if (ruta.contains('/rest/v1/')) {
      final tabla = pedido.url.pathSegments.last;
      final filas = switch (tabla) {
        'tratamientos' => tratamientos,
        'prevenciones' => prevenciones,
        'fichas_bovinas' => animales,
        'vinculaciones' => <Map<String, dynamic>>[
          {
            'cuenta_id': 'demo-cuenta',
            'rol': Granjas.instance.rol.name,
            'cuentas': {
              'nombre': 'Equipo de prueba',
              'identificador': 'demo@example.invalid',
            },
          },
        ],
        _ => <Map<String, dynamic>>[],
      };
      final ficha = pedido.url.queryParameters['ficha_id']?.replaceFirst(
        'eq.',
        '',
      );
      respuesta = filas
          .where((f) => ficha == null || f['ficha_id'] == ficha)
          .toList();
    } else if (ruta.endsWith('/atenciones')) {
      respuesta = atenciones
          .where((a) => ruta.contains('/${a['fichaBovinaId']}/'))
          .toList();
    } else if (ruta.contains('/fichasbovinas')) {
      final filas = [
        for (final a in animales)
          {
            ...a,
            'etapa': (a['etapa'] as String) == 'vaca' ? 'Vaca' : 'Vaquilla',
          },
      ];
      respuesta = ruta.endsWith('/fichasbovinas')
          ? filas
          : filas.firstWhere((a) => ruta.endsWith('/${a['id']}'));
    }
    return http.Response(
      respuesta == null ? '' : jsonEncode(respuesta),
      200,
      request: pedido,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }

  Map<String, dynamic> _tratamientoApi(Map<String, dynamic> fila) => {
    'id': fila['id'],
    'fichaBovinaId': fila['ficha_id'],
    'atencionClinicaId': fila['atencion_id'],
    'cuentaVeterinarioId': fila['prescrito_por'],
    'medicamento': fila['medicamento'],
    'dosis': fila['dosis'],
    'unidad': fila['unidad'],
    'via': fila['via'],
    'frecuencia': fila['frecuencia'],
    'inicio': fila['inicio'],
    'duracion': fila['duracion'],
    'retiro': fila['retiro'],
    'fechaFin': fila['fecha_fin'],
    'motivoFin': fila['motivo_fin'],
    'anteriorId': fila['anterior_id'],
    'anulado': fila['anulado'],
    'version': fila['version'],
  };

  Map<String, dynamic> _prevencionApi(Map<String, dynamic> fila) => {
    'id': fila['id'],
    'fichaBovinaId': fila['ficha_id'],
    'cuentaVeterinarioId': fila['programado_por'],
    'tipo': fila['tipo'],
    'nombre': fila['nombre'],
    'fechaProgramada': fila['fecha_programada'],
    'estado': fila['estado'],
    'fechaRealizacion': fila['fecha_realizacion'],
    'version': fila['version'],
  };
}
