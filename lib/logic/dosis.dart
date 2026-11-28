// 1. Reglas de dosis compartidas por Tratamiento, Prevención y Aplicación (iguales a las de la API).
const unidadesDosis = ['ml', 'mg', 'g', 'UI', 'mg/kg', 'ml/kg', 'comprimido', 'bolo', 'pomo'];

String? unidadValida(String? unidad) {
  final buscada = unidad?.trim().toLowerCase();
  for (final u in unidadesDosis) {
    if (u.toLowerCase() == buscada) return u;
  }
  return null;
}

// 2. "Cada" se guarda como "N h" y "Duración" como "N días".
String textoCada(int horas) => '$horas h';
String textoDuracion(int dias) => '$dias ${dias == 1 ? 'día' : 'días'}';

int? numeroDe(String? texto) {
  final m = RegExp(r'(\d+)').firstMatch(texto ?? '');
  return m == null ? null : int.tryParse(m.group(1)!);
}

bool formatoCada(String texto) => RegExp(r'^\d{1,3}\s*h$', caseSensitive: false).hasMatch(texto.trim());
bool formatoDuracion(String texto) => RegExp(r'^\d{1,3}\s*d[ií]as?$', caseSensitive: false).hasMatch(texto.trim());

// 3. Total de dosis: duración en horas dividida por cada cuántas horas.
int? totalDosis(String? frecuencia, String? duracion) {
  if (frecuencia != null && frecuencia.toLowerCase().contains('única')) return 1;
  final horas = _horas(frecuencia, 1);
  final total = _horas(duracion, 24);
  if (horas == null || total == null || horas <= 0 || total <= 0) return null;
  final n = (total / horas).ceil();
  return n < 1 ? 1 : n;
}

double? _horas(String? texto, double porDefecto) {
  final m = RegExp(r'(\d+(?:[.,]\d+)?)\s*([a-záéíóú]*)', caseSensitive: false).firstMatch(texto ?? '');
  if (m == null) return null;
  final n = double.parse(m.group(1)!.replaceAll(',', '.'));
  final u = m.group(2)!.toLowerCase();
  if (u.startsWith('h')) return n;
  if (u.startsWith('d')) return n * 24;
  if (u.startsWith('s')) return n * 24 * 7;
  return n * porDefecto;
}

String numeroCorto(double valor) =>
    valor == valor.roundToDouble() ? valor.toStringAsFixed(0) : valor.toString().replaceAll('.', ',');
