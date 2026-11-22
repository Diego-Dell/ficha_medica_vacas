import 'package:flutter/material.dart';

import '../logic/granjas.dart';
import '../screens/inicio_por_rol.dart';
import 'vetlink.dart';

/// Menú compartido: Drawer aporta la animación, el fondo y el cierre al deslizar.
class MenuGranjas extends StatefulWidget {
  const MenuGranjas({super.key, required this.alRegistrar});
  final VoidCallback alRegistrar;

  @override
  State<MenuGranjas> createState() => _MenuGranjasState();
}

class _MenuGranjasState extends State<MenuGranjas> {
  late Future<List<Vinculo>> _vinculos = Granjas.instance.misVinculos();

  @override
  Widget build(BuildContext context) => Drawer(
    width: MediaQuery.sizeOf(context).width * .72,
    backgroundColor: const Color(0xFFF7F8F0),
    shape: const RoundedRectangleBorder(),
    child: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar ×', style: TextStyle(color: colorVerde, fontSize: 12))),
          ),
          const SizedBox(height: 8),
          const Text('Mis granjas', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: colorVerdeOscuro)),
          const SizedBox(height: 16),
          FutureBuilder<List<Vinculo>>(
            future: _vinculos,
            builder: (context, estado) {
              if (estado.hasError) {
                return TextButton(onPressed: () {
                  setState(() { _vinculos = Granjas.instance.misVinculos(); });
                }, child: const Text('No se pudieron cargar tus granjas. Reintentar'));
              }
              if (!estado.hasData) return const Center(child: CircularProgressIndicator());
              if (estado.data!.isEmpty) {
                return const Padding(
                padding: EdgeInsets.only(bottom: 16), child: Text('No tenés granjas vinculadas.'));
              }
              return Column(children: [for (final vinculo in estado.data!)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      title: Text(vinculo.granja.nombre, style: const TextStyle(color: colorVerde, fontWeight: FontWeight.w600, fontSize: 15)),
                      subtitle: Text(!vinculo.granja.confirmada
                        ? (vinculo.granja.rechazada ? 'Solicitud rechazada' : 'En revisión')
                        : Granjas.instance.esActual(vinculo.granja) ? 'Granja actual' : 'Granja vinculada',
                        style: const TextStyle(color: colorTextoSuave, fontSize: 12)),
                      trailing: Granjas.instance.esActual(vinculo.granja) ? null : const Icon(Icons.chevron_right, color: colorVerde, size: 18),
                      onTap: () {
                        Navigator.pop(context);
                        InicioPorRol.entrar(context, vinculo);
                      },
                    ),
                  ),
                ),
              ]);
            },
          ),
          BotonPrincipal(texto: 'Registrar otra granja', alPresionar: () {
            Navigator.pop(context);
            widget.alRegistrar();
          }),
        ],
      ),
    ),
  );
}
