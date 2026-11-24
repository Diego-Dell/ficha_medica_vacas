import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ficha_medica_vacas/logic/granjas.dart';
import 'package:ficha_medica_vacas/logic/tratamientos.dart';
import 'package:ficha_medica_vacas/models/animal.dart';
import 'package:ficha_medica_vacas/models/granja.dart';
import 'package:ficha_medica_vacas/models/miembro.dart';
import 'package:ficha_medica_vacas/models/registro_clinico.dart';
import 'package:ficha_medica_vacas/models/tratamiento.dart';

// Esta prueba escribe en Render/Supabase. Se omite salvo habilitación expresa.
// La sesión y las referencias se reciben en memoria mediante el entorno del
// proceso. No guardar tokens, contraseñas ni datos de animales en este archivo.
void main() {
  final habilitada = Platform.environment['VETLINK_REAL_TEST'] == '1';
  test(
    'Guarda por el módulo real, verifica Supabase y anula la prueba',
    () async {
      final entorno = Platform.environment;
      final api = entorno['VETLINK_TEST_API_URL']!;
      final db = SupabaseClient(
        entorno['VETLINK_TEST_SUPABASE_URL']!,
        entorno['VETLINK_TEST_SUPABASE_KEY']!,
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      final cliente = http.Client();
      final evidencia = <String, dynamic>{
        'fecha': DateTime.now().toUtc().toIso8601String(),
        'api': api,
        'guardadoPorModuloFlutter': false,
        'verificadoEnRender': false,
        'verificadoEnSupabase': false,
        'anuladoAlTerminar': false,
      };
      final marca =
          'PRUEBA TECNICA - NO APLICAR - '
          '${DateTime.now().toUtc().microsecondsSinceEpoch}';
      String? creadoId;
      String? fichaId;
      Map<String, String>? headers;
      try {
        await db.auth.setInitialSession(entorno['VETLINK_TEST_SESSION']!);
        final sesion = db.auth.currentSession!;
        headers = {'Authorization': 'Bearer ${sesion.accessToken}'};
        final ficha =
            jsonDecode(entorno['VETLINK_TEST_FICHA']!) as Map<String, dynamic>;
        final atencion = jsonDecode(
          entorno['VETLINK_TEST_ATENCION']!,
        ) as Map<String, dynamic>;
        fichaId = ficha['id'] as String;
        final granjaId = ficha['granjaId'] as String;
        final vinculo = await db
            .from('vinculaciones')
            .select('rol')
            .eq('cuenta_id', sesion.user.id)
            .eq('granja_id', granjaId)
            .eq('activa', true)
            .single();
        expect(vinculo['rol'], 'veterinario');
        expect(ficha['fechaBaja'], isNull);
        expect(atencion['fichaBovinaId'], fichaId);
        expect(atencion['anulado'], isFalse);

        Granjas.instance.conectar(db);
        Granjas.instance.seleccionar((
          granja: Granja(
            id: granjaId,
            nombre: 'Contexto de prueba técnica',
            dueno: '',
            superficie: 0,
            runsa: '',
            documento: '',
            confirmada: true,
          ),
          rol: RolMiembro.veterinario,
        ));
        Tratamientos.instance.usarApi(api, cliente);
        // Usa la conexión real al cliente autenticado, no un token simulado.
        Tratamientos.instance.conectar(db);
        final animal = Animal.desdeApi(ficha);
        final antecedente = RegistroClinico.desdeApi(
          atencion,
          reproductivo: false,
        );
        final hoy = DateTime.now();
        final error = await Tratamientos.instance.guardar(
          animal: animal,
          atencion: antecedente,
          indicacion: IndicacionTratamiento(
            medicamento: marca,
            dosis: 1,
            unidad: 'prueba',
            via: 'NO APLICAR',
            frecuencia: 'Verificación técnica; no administrar',
            inicio: DateTime(hoy.year, hoy.month, hoy.day),
            duracion: 'Prueba técnica, sin uso clínico',
            retiro:
                'Registro sintético para comprobar persistencia; NO APLICAR',
          ),
        );
        expect(error, isNull, reason: error);
        evidencia['guardadoPorModuloFlutter'] = true;
        final lista = await Tratamientos.instance.delAnimal(fichaId);
        final creado = lista.singleWhere((t) => t.medicamento == marca);
        creadoId = creado.id;
        expect(creado.animalId, fichaId);
        expect(creado.atencionId, atencion['id']);
        expect(creado.autorId, sesion.user.id);
        expect(creado.retiro, contains('NO APLICAR'));
        evidencia['verificadoEnRender'] = true;
        evidencia['tratamientoId'] = creadoId;
        final fila = await db
            .from('tratamientos')
            .select(
              'id,ficha_id,atencion_id,prescrito_por,medicamento,dosis,unidad,via,retiro,anulado',
            )
            .eq('id', creadoId)
            .single();
        expect(fila['medicamento'], marca);
        expect(fila['ficha_id'], fichaId);
        expect(fila['atencion_id'], atencion['id']);
        expect(fila['prescrito_por'], sesion.user.id);
        expect(fila['dosis'], 1);
        expect(fila['unidad'], 'prueba');
        expect(fila['via'], 'NO APLICAR');
        expect(fila['retiro'], contains('NO APLICAR'));
        expect(fila['anulado'], isFalse);
        evidencia['verificadoEnSupabase'] = true;
      } catch (error) {
        evidencia['fallo'] = error.toString();
        rethrow;
      } finally {
        try {
          // También localiza el registro si hubo un fallo al interpretar la
          // respuesta de una escritura que sí alcanzó el servidor.
          if (creadoId == null &&
              fichaId != null &&
              db.auth.currentSession != null) {
            final filas = await db
                .from('tratamientos')
                .select('id')
                .eq('ficha_id', fichaId)
                .eq('medicamento', marca);
            if (filas.length == 1) creadoId = filas.single['id'] as String;
          }
          if (creadoId != null && headers != null) {
            final respuesta = await cliente
                .delete(
                  Uri.parse('$api/api/tratamientos/$creadoId'),
                  headers: headers,
                )
                .timeout(const Duration(seconds: 75));
            expect(
              respuesta.statusCode,
              204,
              reason: 'No se pudo anular el registro sintético',
            );
            final fila = await db
                .from('tratamientos')
                .select('anulado')
                .eq('id', creadoId)
                .single();
            expect(fila['anulado'], isTrue);
            evidencia['anuladoAlTerminar'] = true;
            evidencia['tratamientoId'] = creadoId;
          }
        } finally {
          final archivo = entorno['VETLINK_TEST_RESULT'];
          if (archivo != null) {
            File(archivo).writeAsStringSync(
              const JsonEncoder.withIndent('  ').convert(evidencia),
            );
          }
          cliente.close();
          await db.dispose();
        }
      }
    },
    skip: habilitada
        ? false
        : 'Requiere habilitación explícita y sesión de prueba',
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
