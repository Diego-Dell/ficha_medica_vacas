import 'package:flutter/material.dart';
import '../logic/clinica.dart';
import '../logic/granjas.dart';
import '../models/registro_clinico.dart';
import 'vetlink.dart';

// 1. Antecedentes dentro de la ficha, sin crear otra pantalla.
class HistorialClinico extends StatefulWidget {
  const HistorialClinico({super.key, required this.animalId});
  final String animalId;
  @override
  State<HistorialClinico> createState() => _HistorialClinicoState();
}

class _HistorialClinicoState extends State<HistorialClinico> {
  bool _reproductivos = false;
  late Future<List<RegistroClinico>> _registros = _cargar();
  Map<String, String> _autores = {};

  Future<List<RegistroClinico>> _cargar() async {
    final registros = await Clinica.instance.antecedentes(widget.animalId, reproductivos: _reproductivos);
    try {
      final miembros = await Granjas.instance.miembros();
      _autores = {for (final m in miembros) m.cuentaId: m.nombre};
    } on Exception { /* El historial sigue disponible si no se puede resolver el nombre. */ }
    return registros;
  }

  @override
  void didUpdateWidget(covariant HistorialClinico oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animalId != widget.animalId) _registros = _cargar();
  }

  String _fecha(String valor) => fechaCorta(DateTime.parse(valor));

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('Antecedentes', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      DropdownButtonFormField<bool>(
        initialValue: _reproductivos,
        decoration: decoracionCampo(),
        items: const [DropdownMenuItem(value: false, child: Text('Clínicos')), DropdownMenuItem(value: true, child: Text('Reproductivos'))],
        onChanged: (valor) => setState(() { _reproductivos = valor!; _registros = _cargar(); }),
      ),
      TextButton(onPressed: () => setState(() => _registros = _cargar()), child: const Text('Actualizar antecedentes')),
      FutureBuilder<List<RegistroClinico>>(
        future: _registros,
        builder: (context, estado) {
          if (estado.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (estado.hasError) return Text(estado.error.toString(), style: const TextStyle(color: colorRojo));
          final registros = estado.data ?? [];
          if (registros.isEmpty) return const Text('Todavía no hay registros de este tipo.');
          return Column(children: [for (final r in registros)
            Padding(padding: const EdgeInsets.only(bottom: 12), child: Tarjeta(child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('${fechaCorta(r.fecha)} · ${r.titulo}${r.anulado ? ' · Anulado' : ''}', style: Theme.of(context).textTheme.labelLarge),
                if (r.reproductivo) ...[
                  Text('Aptitud: ${r.aptitudTexto}'), Text('Preñez: ${r.prenezTexto}'),
                  if (r.proximoControl != null) Text('Próximo control: ${_fecha(r.proximoControl!)}'),
                  if (r.partoProbable != null) Text('Parto probable: ${_fecha(r.partoProbable!)}'),
                ],
                if (r.detalle.isNotEmpty) Text(r.detalle),
                const SizedBox(height: 6),
                Text(_autores[r.autorId] ?? 'Veterinario · nombre no disponible', style: Theme.of(context).textTheme.bodySmall),
              ],
            ))),
          ]);
        },
      ),
    ],
  );
}
