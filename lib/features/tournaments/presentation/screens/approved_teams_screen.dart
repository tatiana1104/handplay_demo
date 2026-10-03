import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../shared/constants/uniform_colors.dart';
import '../../../teams/data/team_repository.dart';
import '../../../teams/presentation/screens/team_detail_screen.dart';
import '../../domain/models/tournament_models.dart';

class ApprovedTeamsScreen extends StatelessWidget {
  const ApprovedTeamsScreen({required this.tournament, super.key});

  final Tournament tournament;

  @override
  Widget build(BuildContext context) {
    final stream = TeamRepository().watchTournamentRegistrationDocuments(tournament.id);

    return Scaffold(
      appBar: AppBar(title: const Text('Equipos inscritos')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('No se pudieron cargar los equipos.'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final teams = snapshot.data!.docs;
          if (teams.isEmpty) {
            return const Center(child: Text('Aún no hay equipos aprobados.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: teams.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final data = teams[index].data();
              final players = data['players'] as List?;
              final name = data['teamName']?.toString().trim().isNotEmpty == true
                  ? data['teamName'].toString()
                  : 'Equipo sin nombre';
              final teamColor = UniformColors.resolve(data['uniformColor'] ?? data['jerseyColor'] ?? data['kitColor'] ?? data['color']);

              return Card(
                margin: EdgeInsets.zero,
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TeamDetailScreen(
                        tournament: tournament,
                        registrationId: teams[index].id,
                        registration: data,
                        teamColor: teamColor,
                      ),
                    ),
                  ),
                  leading: CircleAvatar(
                    backgroundColor: teamColor,
                    foregroundColor: UniformColors.contrast(teamColor),
                    child: Text(name.substring(0, 1).toUpperCase()),
                  ),
                  title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('${players?.length ?? data['playerCount'] ?? 0} jugadores'),
                  trailing: const Icon(Icons.chevron_right),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
