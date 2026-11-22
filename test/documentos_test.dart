import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ficha_medica_vacas/logic/documentos.dart';
import 'package:ficha_medica_vacas/logic/granjas.dart';
import 'apoyo.dart';
import 'package:ficha_medica_vacas/models/granja.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temporal;
  const pendiente = 'pendiente/0123456789abcdef0123456789abcdef/terreno.pdf';
  final pdf = Uint8List.fromList(utf8.encode('%PDF-1.4\ncontenido de prueba'));
  setUp(() async {
    temporal = await Directory.systemTemp.createTemp('vetlink-documentos-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'), (_) async => temporal.path);
  });
  tearDown(() async {
    await temporal.delete(recursive: true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'), null);
  });

  test('Valida contenido, tamaño y rutas antes de leer archivos', () async {
    expect(Documentos.tipo('terreno.pdf', pdf), 'application/pdf');
    expect(() => Documentos.tipo('falso.pdf', Uint8List.fromList([1,2,3])), throwsFormatException);
    expect(() => Documentos.tipo('imagen.jpg', Uint8List.fromList([255,216,255])), throwsFormatException);
    expect(() => Documentos.tipo('grande.pdf', Uint8List(Documentos.limite + 1)), throwsFormatException);
    await expectLater(Documentos.local('pendiente/../../secreto.pdf'), throwsFormatException);
  });

  test('No crea una granja si el PDF seleccionado no existe', () async {
    final pedidos = <http.Request>[];
    Granjas.instance.cliente = SupabaseClient('https://prueba.supabase.co', 'clave',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((r) async { pedidos.add(r); return http.Response('{}', 200); }));
    final error = await Granjas.instance.registrarGranja(const Granja(nombre: 'Nueva',
      dueno: 'Ana', superficie: 1, runsa: 'TEST', documento: pendiente));
    expect(error, isNotNull);
    expect(pedidos, isEmpty);
  });

  for (final fallaSubida in [false, true]) {
    test(fallaSubida ? 'No registra si falla subir el PDF' : 'Registra solamente después de subir el PDF', () async {
      final archivo = await Documentos.local(pendiente);
      await archivo.parent.create(recursive: true);
      await archivo.writeAsBytes(pdf);
      final pedidos = <http.Request>[];
      Granjas.instance.cliente = SupabaseClient('https://prueba.supabase.co', 'clave',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((r) async {
          pedidos.add(r);
          if (r.url.path.contains('/storage/')) {
            return http.Response(
            fallaSubida ? '{"message":"error","statusCode":403,"error":"denegado"}' : '{"Key":"pdf"}',
            fallaSubida ? 403 : 200, headers: {'content-type':'application/json'}, request: r);
          }
          return http.Response('"01234567-89ab-cdef-0123-456789abcdef"', 200,
            headers: {'content-type':'application/json'}, request: r);
        }));
      final error = await Granjas.instance.registrarGranja(const Granja(nombre: 'Nueva',
        dueno: 'Ana', superficie: 1, runsa: 'TEST', documento: pendiente));
      expect(error, fallaSubida ? isNotNull : isNull);
      expect(pedidos.length, fallaSubida ? 1 : 2);
      expect(pedidos.first.url.path, contains('/storage/v1/object/'));
      if (!fallaSubida) {
        expect(pedidos.last.url.path, endsWith('/rpc/registrar_granja'));
        expect(jsonDecode(pedidos.last.body)['p_documentos'], startsWith('storage/'));
      }
      expect(await archivo.exists(), fallaSubida);
    });
  }

  for (final falla in [false, true]) {
    test(falla ? 'Conserva el archivo si falla guardar la ruta' : 'Sube bytes y guarda ruta privada antes de limpiar la copia', () async {
      final archivo = await Documentos.local(pendiente);
      await archivo.parent.create(recursive: true);
      await archivo.writeAsBytes(pdf);
      final pedidos = <http.Request>[];
      Granjas.instance.cliente = SupabaseClient('https://prueba.supabase.co', 'clave',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((r) async {
          pedidos.add(r);
          if (r.url.path.endsWith('adjuntar_documento_granja')) {
            return http.Response(jsonEncode(falla ? {'message':'denegado','code':'42501'} : {'id':'g1'}), falla ? 403 : 200,
              headers: {'content-type':'application/json'}, request: r);
          }
          return http.Response('{"Key":"archivo"}', 200, headers: {'content-type':'application/json'});
        }));
      final error = await Granjas.instance.subirDocumento(losPinos, pendiente);
      expect(error, falla ? isNotNull : isNull);
      expect(await archivo.exists(), falla);
      expect(pedidos.first.url.path, contains('/storage/v1/object/documentos-granjas/'));
      expect(utf8.decode(pedidos.first.bodyBytes, allowMalformed: true), contains('%PDF-1.4'));
      final ruta = (jsonDecode(pedidos.last.body) as Map)['p_ruta'] as String;
      expect(jsonDecode(pedidos.last.body)['p_granja'], 'g1');
      expect(ruta, endsWith('/g1/0123456789abcdef0123456789abcdef/terreno.pdf'));
    });
  }

  test('Un nombre antiguo no genera un enlace a un archivo inexistente', () {
    expect(() => Granjas.instance.enlaceDocumento(losPinos), throwsFormatException);
  });
  test('Genera enlace privado de cinco minutos sin publicarlo en la granja', () async {
    late http.Request pedido;
    Granjas.instance.cliente = SupabaseClient('https://prueba.supabase.co', 'clave',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((r) async {
        pedido = r;
        return http.Response('{"signedURL":"/object/sign/documentos-granjas/prueba.pdf?token=prueba"}', 200,
          headers: {'content-type':'application/json'}, request: r);
      }));
    const granja = Granja(id: 'g1', nombre: 'Prueba', dueno: 'Prueba', superficie: 1,
      runsa: 'prueba', documento: 'storage/dueno/g1/documento.pdf');
    final url = await Granjas.instance.enlaceDocumento(granja);
    expect(pedido.url.path, endsWith('/object/sign/documentos-granjas/dueno/g1/documento.pdf'));
    expect(jsonDecode(pedido.body)['expiresIn'], 300);
    expect(url, startsWith('https://prueba.supabase.co/storage/v1/object/sign/'));
  });

}
