enum Etapa {
  ternera('Ternera'),
  vaquilla('Vaquilla'),
  vaca('Vaca');

  const Etapa(this.etiqueta);
  final String etiqueta;
}

class Animal {
  const Animal({
    this.id = '',
    required this.arete,
    this.nombre,
    this.raza,
    required this.etapa,
    this.nacimiento,
    this.nacimientoEstimado = false,
    this.fechaBaja,
    this.motivoBaja,
  });

  // 1. Crea el animal desde una fila de Supabase.
  factory Animal.fromMap(Map<String, dynamic> fila) => Animal(
        id: fila['id'] as String,
        arete: fila['identificacion'] as String,
        nombre: fila['nombre'] as String?,
        raza: fila['raza'] as String?,
        etapa: Etapa.values.byName(fila['etapa'] as String),
        nacimiento: _fecha(fila['nacimiento']),
        nacimientoEstimado: fila['nacimiento_estimado'] as bool? ?? false,
        fechaBaja: _fecha(fila['fecha_baja']),
        motivoBaja: fila['motivo_baja'] as String?,
      );

  // 4. Crea el animal desde la respuesta de la API (camelCase y etapa con mayúscula).
  factory Animal.desdeApi(Map<String, dynamic> datos) => Animal(
        id: datos['id'] as String,
        arete: datos['identificacion'] as String,
        nombre: datos['nombre'] as String?,
        raza: datos['raza'] as String?,
        etapa: Etapa.values.byName((datos['etapa'] as String).toLowerCase()),
        nacimiento: _fecha(datos['nacimiento']),
        nacimientoEstimado: datos['nacimientoEstimado'] as bool? ?? false,
        fechaBaja: _fecha(datos['fechaBaja']),
        motivoBaja: datos['motivoBaja'] as String?,
      );

  // 5. Datos generales en el formato de la API.
  Map<String, dynamic> paraApi() => {
        'identificacion': arete,
        'nombre': nombre,
        'raza': raza,
        'etapa': etapa.etiqueta,
        'nacimiento': nacimiento?.toIso8601String().substring(0, 10),
        'nacimientoEstimado': nacimientoEstimado,
      };

  final String id;
  final String arete;
  final String? nombre;
  final String? raza;
  final Etapa etapa;
  final DateTime? nacimiento;
  final bool nacimientoEstimado;
  final DateTime? fechaBaja;
  final String? motivoBaja;

  bool get deBaja => fechaBaja != null;

  // 2. Nombre e identificación, o solo la identificación.
  String get titulo => nombre == null ? arete : '$nombre · $arete';

  // 3. Datos generales que se guardan; la baja va aparte.
  Map<String, dynamic> datosGenerales() => {
        'identificacion': arete,
        'nombre': nombre,
        'raza': raza,
        'etapa': etapa.name,
        'nacimiento': nacimiento?.toIso8601String().substring(0, 10),
        'nacimiento_estimado': nacimientoEstimado,
      };

  static DateTime? _fecha(Object? valor) => valor == null ? null : DateTime.parse(valor as String);
}
