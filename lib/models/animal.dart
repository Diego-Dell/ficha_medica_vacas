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

  /// 1. Crea el animal a partir de una ficha de Supabase.
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

  final String id;

  /// Identificación única del animal dentro de su granja (arete u otro código).
  final String arete;
  final String? nombre;
  final String? raza;
  final Etapa etapa;
  final DateTime? nacimiento;
  final bool nacimientoEstimado;
  final DateTime? fechaBaja;
  final String? motivoBaja;

  bool get deBaja => fechaBaja != null;

  /// 2. Escribe el nombre con el arete, o solo el arete si no tiene nombre.
  String get titulo => nombre == null ? arete : '$nombre · $arete';

  /// 3. Arma los datos generales que se guardan en la ficha; la baja se guarda aparte.
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
