import 'package:flutter/material.dart';

import '../../../../shared/widgets/placeholder_screen.dart'; // Importamos un widget de marcador de posición para mostrar mientras se desarrolla la pantalla de torneos

// Esta es la pantalla "Inicio" que ve cualquier persona
// (RouteNames.home). Según el mockup "Mis torneos": lista de torneos
// separados en pestañas Activos/Finalizados, cada uno con una barra de
// progreso de jornada (ej. "J7/9") y el próximo partido programado.
// El ícono de estrella (★/☆) marca/desmarca un torneo como favorito
// (RF-04, UC-10).

/// TODO(Sprint 2): reemplazar por la lista real de torneos (RF-03),
/// con:
/// - `TorneosBloc` que pida a Firestore los torneos donde el usuario
///   tiene algún rol relevante (o todos, si es espectador).
/// - Filtro por pestañas Activos/Finalizados.
/// - Toggle de favorito por torneo (RF-04), guardado en el documento
///   del usuario o en una subcolección `favoritos`.
class TorneosScreen extends StatelessWidget {
  const TorneosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(titulo: 'Mis torneos');
  }
}
