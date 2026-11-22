import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

/// Conserva el archivo hasta confirmar el correo, incluso si se cierra la app.
abstract final class Documentos {
  static const bucket = 'documentos-granjas';
  static const limite = 10 * 1024 * 1024;
  static String nombre(String ruta) => ruta.split('/').last;
  static bool subido(String ruta) => ruta.startsWith('storage/');

  static String tipo(String nombre, Uint8List bytes) {
    final extension = nombre.split('.').last.toLowerCase();
    bool inicia(List<int> firma) => bytes.length >= firma.length &&
        List.generate(firma.length, (i) => bytes[i] == firma[i]).every((v) => v);
    if (bytes.isEmpty || bytes.length > limite) throw const FormatException('El archivo debe tener contenido y pesar hasta 10 MB');
    if (extension == 'pdf' && inicia([37, 80, 68, 70, 45])) return 'application/pdf';
    throw const FormatException('Elegí un PDF válido de hasta 10 MB');
  }

  static Future<File> local(String ruta) async {
    if (!RegExp(r'^pendiente/[a-f0-9]{32}/[^/\\]+$').hasMatch(ruta)) {
      throw const FormatException('Seleccioná nuevamente el documento');
    }
    final carpeta = await getApplicationSupportDirectory();
    return File('${carpeta.path}/documentos/$ruta');
  }

  static Future<String?> elegir() async {
    final archivos = await FilePicker.pickFiles(type: FileType.custom,
      allowedExtensions: const ['pdf']);
    if (archivos.isEmpty) return null;
    final archivo = archivos.first;
    if ((await archivo.length() ?? limite + 1) > limite) {
      throw const FormatException('El archivo debe pesar hasta 10 MB');
    }
    final bytes = await archivo.readAsBytes();
    tipo(archivo.name, bytes);
    final id = List.generate(16, (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0')).join();
    final nombreSeguro = archivo.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final ruta = 'pendiente/$id/$nombreSeguro';
    final destino = await local(ruta);
    await destino.parent.create(recursive: true);
    await destino.writeAsBytes(bytes, flush: true);
    return ruta;
  }
}
