import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../domain/models/tournament_models.dart';
import '../utils/standings_calculator.dart';

class TournamentStandingsSummary extends StatelessWidget {
  const TournamentStandingsSummary({required this.tournament, super.key});

  final Tournament tournament;

  @override
  Widget build(BuildContext context) => TournamentStandingsData(
    tournament: tournament,
    builder: (rows) {
      final leader = rows.isEmpty ? null : rows.first;
      return Card(
        child: ListTile(
          leading: const CircleAvatar(child: Text('1')),
          title: Text(
            leader?.team ?? 'Aún no hay equipos clasificados',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: leader == null
              ? null
              : Text('${leader.points} pts · DG ${leader.goalDifference}'),
        ),
      );
    },
  );
}

class TournamentStandingsData extends StatelessWidget {
  const TournamentStandingsData({
    required this.tournament,
    required this.builder,
    super.key,
  });

  final Tournament tournament;
  final Widget Function(List<StandingEntry> rows) builder;

  bool _isApprovedLineup(Map<String, dynamic> data) {
    final value =
        data['lineupStatus'] ??
        data['rosterStatus'] ??
        data['planillaStatus'] ??
        data['lineup_status'];
    final normalized = value?.toString().trim().toLowerCase();
    return normalized == 'approved' ||
        normalized == 'aprobada' ||
        normalized == 'aprobado';
  }

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('tournaments')
            .doc(tournament.id)
            .collection('registrations')
            .snapshots(),
        builder: (context, registrations) =>
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('tournaments')
                  .doc(tournament.id)
                  .collection('matches')
                  .snapshots(),
              builder: (context, matches) {
                final approvedRegistrations =
                    (registrations.data?.docs ?? const []).where((doc) {
                      final data = doc.data();
                      final status = data['status']
                          ?.toString()
                          .trim()
                          .toLowerCase();
                      return status == 'approved' ||
                          status == 'aprobada' ||
                          status == 'aprobado';
                    }).toList();

                final approvedMatches = (matches.data?.docs ?? const []).where((
                  doc,
                ) {
                  final data = doc.data();
                  return _isApprovedLineup(data);
                }).toList();

                return builder(
                  calculateStandings(
                    registrations: approvedRegistrations,
                    matches: approvedMatches,
                  ),
                );
              },
            ),
      );
}

class TournamentStandingsFullScreen extends StatelessWidget {
  const TournamentStandingsFullScreen({required this.tournament, super.key});

  final Tournament tournament;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Tabla de posiciones')),
    body: TournamentStandingsData(
      tournament: tournament,
      builder: (rows) {
        if (rows.isEmpty) {
          return const Center(
            child: Text('Aún no hay posiciones para mostrar.'),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: rows.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final row = rows[index];
            return Card(
              child: ListTile(
                leading: CircleAvatar(child: Text('${index + 1}')),
                title: Text(
                  row.team,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  '${row.points} pts · ${row.wins}-${row.draws}-${row.losses}',
                ),
                trailing: Text(
                  '${row.goalDifference} GD',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            );
          },
        );
      },
    ),
  );
}
