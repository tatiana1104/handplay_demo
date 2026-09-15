import 'package:flutter/material.dart';

import 'app_bottom_navigation_bar.dart';

// Este widget existe solo para que el router (app_router.dart) tenga
// algo real para mostrar en rutas cuya pantalla definitiva todavía no
// se ha construido. Así podemos navegar por TODA la app desde el
// Sprint 1 (probar que los links funcionan) aunque el contenido real
// se vaya llenando sprint a sprint.

/// Pantalla temporal usada por el router para rutas cuya feature
/// todavía no se ha implementado.
///
/// Se van eliminando los usos de este widget a medida que cada
/// pantalla real (ver backlog en Seguimiento_de_item.docx) queda
/// terminada — cuando ya no quede ningún `PlaceholderScreen` en
/// `app_router.dart`, la app está funcionalmente completa.
class PlaceholderScreen extends StatelessWidget {
  /// Texto que se muestra en la barra superior y en el cuerpo, para
  /// identificar qué pantalla falta por construir.
  final String titulo;

  const PlaceholderScreen({super.key, required this.titulo});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(titulo)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '"$titulo" — pantalla pendiente de implementar.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ),
      bottomNavigationBar: const AppBottomNavigationBar(),
    );
  }
}
