import 'package:flutter/material.dart';

import '../../domain/models/team_member_models.dart';

class TeamMembersSummary extends StatelessWidget {
  const TeamMembersSummary({super.key, required this.team});

  final TeamRegistrationModel team;

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

class CoachSummary extends StatelessWidget {
  const CoachSummary({super.key, required this.coach});

  final CoachModel coach;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.sports),
      title: Text(coach.name),
      subtitle: Text(coach.email ?? coach.phone ?? 'Sin contacto registrado'),
    );
  }
}
