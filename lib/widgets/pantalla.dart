import 'package:flutter/material.dart';

import 'vetlink.dart';

/// Marco visual de las cuatro pantallas rediseñadas. Mantiene el encabezado fijo.
class Pantalla extends StatelessWidget {
  const Pantalla({
    super.key,
    required this.titulo,
    required this.children,
    this.subtitulo,
    this.volver = true,
    this.barraInferior,
    this.granja,
    this.rol,
  });

  final String titulo;
  final String? subtitulo;
  final List<Widget> children;
  final bool volver;
  final Widget? barraInferior;
  final String? granja;
  final String? rol;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Theme(
      data: tema.copyWith(
        textTheme: tema.textTheme.copyWith(
          bodyLarge: tema.textTheme.bodyLarge?.copyWith(fontSize: 14),
          bodyMedium: tema.textTheme.bodyMedium?.copyWith(fontSize: 13),
        ),
        inputDecorationTheme: tema.inputDecorationTheme.copyWith(
          isDense: true,
          contentPadding: const EdgeInsets.all(12),
        ),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8F0),
        bottomNavigationBar: barraInferior,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 390),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    child: SizedBox(
                      height: 48,
                      child: Row(
                        children: [
                          Image.asset(
                            'assets/images/logo.png',
                            width: 34,
                            height: 34,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'VetLink',
                                  style: TextStyle(
                                    color: Color(0xFF263F31),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (granja != null)
                                  Text(
                                    granja!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: colorTextoSuave,
                                      fontSize: 11,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (volver)
                            TextButton(
                              onPressed: () => Navigator.maybePop(context),
                              child: const Text(
                                '‹ Volver',
                                style: TextStyle(
                                  color: colorVerde,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (rol != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          rol!,
                          style: const TextStyle(
                            color: colorVerde,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            titulo,
                            style: const TextStyle(
                              color: Color(0xFF263F31),
                              fontSize: 25,
                              height: 1.4,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (subtitulo != null) ...[
                            Text(
                              subtitulo!,
                              style: const TextStyle(
                                color: Color(0xFF687365),
                                fontSize: 13,
                                height: 19 / 13,
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                          ...children,
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
