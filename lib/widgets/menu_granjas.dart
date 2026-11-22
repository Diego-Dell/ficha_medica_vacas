import 'package:flutter/material.dart';

import '../logic/granjas.dart';
import '../screens/inicio_por_rol.dart';
import 'vetlink.dart';

// 1. Hoja inferior "Cambiar de granja": lista las granjas de la cuenta.
class MenuGranjas extends StatefulWidget {
  const MenuGranjas({super.key, required this.alRegistrar});
  final VoidCallback alRegistrar;

  @override
  State<MenuGranjas> createState() => _MenuGranjasState();
}

class _MenuGranjasState extends State<MenuGranjas> {
  late Future<List<Vinculo>> _vinculos = Granjas.instance.misVinculos();

  // 2. Estado que se muestra debajo del nombre.
  String _estado(Vinculo v) {
    if (!v.granja.confirmada) return v.granja.rechazada ? 'Solicitud rechazada' : 'En revisión';
    return v.rol.etiqueta;
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Cambiar de granja', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              FutureBuilder<List<Vinculo>>(
                future: _vinculos,
                builder: (context, estado) {
                  if (estado.hasError) {
                    return TextButton(
                      onPressed: () => setState(() => _vinculos = Granjas.instance.misVinculos()),
                      child: const Text('No se pudieron cargar tus granjas. Reintentar'),
                    );
                  }
                  if (!estado.hasData) return const Center(child: CircularProgressIndicator());
                  if (estado.data!.isEmpty) {
                    return const Padding(padding: EdgeInsets.only(bottom: 16), child: Text('No tenés granjas vinculadas.'));
                  }
                  return Column(
                    children: [
                      for (final vinculo in estado.data!) _fila(context, vinculo),
                    ],
                  );
                },
              ),
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  widget.alRegistrar();
                },
                icon: const Icono('agregar', color: colorVerde, tam: 20),
                label: const Text('Registrar otra granja'),
                style: TextButton.styleFrom(foregroundColor: colorVerde, minimumSize: const Size.fromHeight(48)),
              ),
            ],
          ),
        ),
      );

  Widget _fila(BuildContext context, Vinculo vinculo) {
    final actual = Granjas.instance.esActual(vinculo.granja);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: actual ? colorVerdeSuave : colorSuperficie,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radioTarjeta),
          side: actual ? BorderSide.none : const BorderSide(color: colorBorde),
        ),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          leading: BurbujaIcono('granja', tam: 40, fondo: actual ? colorSuperficie : colorVerdeSuave),
          title: Text(vinculo.granja.nombre, style: Theme.of(context).textTheme.titleMedium),
          subtitle: Text(_estado(vinculo), style: Theme.of(context).textTheme.bodySmall),
          trailing: actual ? const Icono('check', color: colorVerde, tam: 20) : null,
          onTap: () {
            Navigator.pop(context);
            if (!actual) InicioPorRol.entrar(context, vinculo);
          },
        ),
      ),
    );
  }
}
