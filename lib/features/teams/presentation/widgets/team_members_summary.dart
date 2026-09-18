import 'package:flutter/material.dart';

import '../../domain/models/team_member_models.dart';

class TeamMembersSummary extends StatelessWidget {
  const TeamMembersSummary({required this.team, super.key});
  final TeamRegistrationModel team;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(team.name, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('Entrenador: ${team.coach.name}'),
            const SizedBox(height: 10),
            Text('${team.players.length} jugadores inscritos'),
            if (team.players.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...team.players.take(5).map((player) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(child: Text(player.number ?? '-')),
                    title: Text(player.name),
                    subtitle: Text(player.position ?? 'Posición no registrada'),
                  )),
            ],
          ]),
        ),
      );
}
