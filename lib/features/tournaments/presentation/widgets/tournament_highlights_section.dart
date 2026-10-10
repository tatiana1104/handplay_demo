import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../shared/widgets/compact_action_card.dart';
import '../../domain/models/tournament_models.dart';
import '../utils/highlight_entries_calculator.dart';

export '../utils/highlight_entries_calculator.dart'
    show TournamentHighlightEntry, TournamentHighlightType;

class TournamentHighlightsSection extends StatelessWidget {
  const TournamentHighlightsSection({required this.tournament, super.key});

  final Tournament tournament;

  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: FirebaseFirestore.instance
        .collection('tournaments')
        .doc(tournament.id)
        .collection('matches')
        .snapshots(),
    builder: (context, matchSnapshot) =>
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('tournaments')
              .doc(tournament.id)
              .collection('registrations')
              .snapshots(),
          builder: (context, registrationSnapshot) {
            final registrations = registrationSnapshot.data?.docs ?? const [];
            final matches = matchSnapshot.data?.docs ?? const [];

            String bestScorer(TournamentHighlightType type) {
              final rows = computeHighlightEntries(
                type: type,
                registrations: registrations.map((d) => (id: d.id, data: d.data())),
                matches: matches.map((d) => d.data()),
              );
              if (rows.isEmpty || rows.first.value == 0) return 'Sin datos';
              return '${rows.first.name} · ${rows.first.value} goles';
            }

            String bestGoalkeeper() {
              final rows = computeHighlightEntries(
                type: TournamentHighlightType.goalkeepers,
                registrations: registrations.map((d) => (id: d.id, data: d.data())),
                matches: matches.map((d) => d.data()),
              );
              if (rows.isEmpty) return 'Sin datos';
              return '${rows.first.name} · ${rows.first.value} goles recibidos';
            }

            return Column(
              children: [
                if (tournament.shouldShowMaleScorers)
                  CompactActionCard(
                    icon: Icons.emoji_events_outlined,
                    title: 'Goleador masculino',
                    subtitle: 'Goles acumulados',
                    value: bestScorer(TournamentHighlightType.maleScorers),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TournamentHighlightsFullScreen(
                          tournament: tournament,
                          type: TournamentHighlightType.maleScorers,
                        ),
                      ),
                    ),
                  ),
                if (tournament.shouldShowFemaleScorers)
                  CompactActionCard(
                    icon: Icons.emoji_events_outlined,
                    title: 'Goleadora femenina',
                    subtitle: 'Goles acumulados',
                    value: bestScorer(TournamentHighlightType.femaleScorers),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TournamentHighlightsFullScreen(
                          tournament: tournament,
                          type: TournamentHighlightType.femaleScorers,
                        ),
                      ),
                    ),
                  ),
                CompactActionCard(
                  icon: Icons.shield_outlined,
                  title: 'Valla menos vencida',
                  subtitle: 'Menos goles recibidos',
                  value: bestGoalkeeper(),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TournamentHighlightsFullScreen(
                        tournament: tournament,
                        type: TournamentHighlightType.goalkeepers,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
  );
}

class TournamentHighlightsFullScreen extends StatelessWidget {
  const TournamentHighlightsFullScreen({
    required this.tournament,
    required this.type,
    super.key,
  });

  final Tournament tournament;
  final TournamentHighlightType type;

  Future<List<TournamentHighlightEntry>> _loadEntries() async {
    final ref = FirebaseFirestore.instance
        .collection('tournaments')
        .doc(tournament.id);
    final registrationSnapshot = await ref.collection('registrations').get();
    final matchSnapshot = await ref.collection('matches').get();
    return computeHighlightEntries(
      type: type,
      registrations: registrationSnapshot.docs.map(
        (d) => (id: d.id, data: d.data()),
      ),
      matches: matchSnapshot.docs.map((d) => d.data()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (type) {
      TournamentHighlightType.maleScorers => 'Goleadores masculinos',
      TournamentHighlightType.femaleScorers => 'Goleadoras femeninas',
      TournamentHighlightType.goalkeepers => 'Valla menos vencida',
    };

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: FutureBuilder<List<TournamentHighlightEntry>>(
        future: _loadEntries(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final rows = snapshot.data!;
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: rows.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, index) => Card(
              child: ListTile(
                leading: CircleAvatar(child: Text('${index + 1}')),
                title: Text(rows[index].name),
                subtitle: Text(rows[index].team ?? ''),
                trailing: Text(
                  type == TournamentHighlightType.goalkeepers
                      ? '${rows[index].value} GC'
                      : '${rows[index].value} goles',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
