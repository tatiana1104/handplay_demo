import 'package:flutter/material.dart';

import '../../../../shared/widgets/placeholder_screen.dart'; // Importamos un widget de marcador de posición para mostrar mientras se desarrolla la pantalla de torneos

// Esta es la pantalla "Inicio" que ve cualquier persona
// (RouteNames.home). Según el mockup "Mis torneos", muestra todos los
// torneos disponibles organizados por estado: activos, próximos y
// finalizados.

/// TODO(Sprint 2): reemplazar por la lista real de torneos (RF-03),
/// con:
/// - `TorneosBloc` que pida a Firestore todos los torneos disponibles.
/// - Filtros por estado, categoría y fecha.
/// - Estados vacíos, de carga y de error de conexión.
class TorneosScreen extends StatelessWidget {
  const TorneosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(titulo: 'Mis torneos');
  }
}
