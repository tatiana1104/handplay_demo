import 'package:flutter/material.dart';

import '../../domain/models/team_member_models.dart';

/// ES: Resume el equipo, su entrenador y la plantilla registrada.
/// EN: Summarizes a team, its coach, and its registered roster.
class TeamMembersSummary extends StatelessWidget {
  /// ES: Crea el resumen para el equipo indicado.
  /// EN: Creates a summary for the supplied team.
  const TeamMembersSummary({super.key, required this.team});

  final TeamRegistrationModel team;

  /// ES: Construye la tarjeta con los datos principales de la plantilla.
  /// EN: Builds the card with the roster's main details.
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(team.name, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Entrenador: ${team.coach.name}'),
            const SizedBox(height: 12),
            Text('Jugadores (${team.players.length})', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            if (team.players.isEmpty)
              const Text('Sin jugadores registrados')
            else
              ...team.players.map((player) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: CircleAvatar(child: Text(player.number ?? '-')),
                    title: Text(player.name),
                    subtitle: Text(player.position ?? 'Posición no definida'),
                  )),
          ],
        ),
      ),
    );
  }
}

/// ES: Muestra el nombre y un medio de contacto del entrenador.
/// EN: Displays the coach's name and one contact method.
class CoachSummary extends StatelessWidget {
  /// ES: Crea el resumen del entrenador indicado.
  /// EN: Creates a summary for the supplied coach.
  const CoachSummary({super.key, required this.coach});

  final CoachModel coach;

  /// ES: Construye una fila compacta con los datos del entrenador.
  /// EN: Builds a compact row with the coach's details.
  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.sports),
      title: Text(coach.name),
      subtitle: Text(coach.email ?? coach.phone ?? 'Sin contacto registrado'),
    );
  }
}
