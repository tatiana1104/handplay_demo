import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../shared/widgets/compact_action_card.dart';
import '../../domain/models/tournament_models.dart';

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

            bool isApprovedLineup(Map<String, dynamic> data) {
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

            final playerInfo = <String, Map<String, dynamic>>{};
            for (final registration in registrations) {
              final data = registration.data();
              final status = data['status']?.toString().trim().toLowerCase();
              if (status != 'approved' &&
                  status != 'aprobada' &&
                  status != 'aprobado')
                continue;
              final players = data['players'];
              if (players is! List) continue;

              for (final rawPlayer in players) {
                if (rawPlayer is! Map) continue;
                final player = Map<String, dynamic>.from(rawPlayer);
                final key =
                    (player['id'] ??
                            player['uid'] ??
                            player['playerId'] ??
                            player['name'] ??
                            player['nombre'])
                        ?.toString()
                        .trim();
                if (key != null && key.isNotEmpty) playerInfo[key] = player;
              }
            }

            final goals = <String, int>{};
            final goalsByTeam = <String, int>{};
            for (final match in matches) {
              final data = match.data();
              final status = data['status']?.toString().toLowerCase();
              if (![
                'finished',
                'finished_match',
                'completed',
                'complete',
                'finalizado',
                'finalizada',
              ].contains(status))
                continue;
              if (!isApprovedLineup(data)) continue;

              final events = data['finalEvents'] ?? data['events'];
              if (events is List) {
                for (final rawEvent in events) {
                  if (rawEvent is! Map ||
                      rawEvent['type']?.toString() != 'goal')
                    continue;
                  final name =
                      (rawEvent['playerName'] ??
                              rawEvent['player'] ??
                              'Jugador')
                          .toString();
                  goals[name] = (goals[name] ?? 0) + 1;
                }
              }

              final home =
                  data['homeTeamId']?.toString() ??
                  data['homeTeam']?.toString();
              final away =
                  data['awayTeamId']?.toString() ??
                  data['awayTeam']?.toString();
              final homeGoals =
                  int.tryParse(
                    '${data['finalHomeScore'] ?? data['homeScore'] ?? 0}',
                  ) ??
                  0;
              final awayGoals =
                  int.tryParse(
                    '${data['finalAwayScore'] ?? data['awayScore'] ?? 0}',
                  ) ??
                  0;

              String teamKey(Object value) =>
                  value.toString().trim().toLowerCase();

              if (home != null)
                goalsByTeam[teamKey(home)] =
                    (goalsByTeam[teamKey(home)] ?? 0) + awayGoals;
              if (away != null)
                goalsByTeam[teamKey(away)] =
                    (goalsByTeam[teamKey(away)] ?? 0) + homeGoals;
            }

            String bestBy(bool female) {
              final eligible = goals.entries.where((entry) {
                final player = playerInfo[entry.key];
                final gender =
                    player?['gender'] ?? player?['genero'] ?? player?['sex'];
                return gender == null ||
                    gender.toString().toLowerCase().contains(
                      female ? 'fem' : 'masc',
                    );
              }).toList()..sort((a, b) => b.value.compareTo(a.value));
              return eligible.isEmpty
                  ? 'Sin datos'
                  : '${eligible.first.key} · ${eligible.first.value} goles';
            }

            String bestGoalkeeper() {
              final candidates = <String, int>{};
              for (final registration in registrations) {
                final data = registration.data();
                final players = data['players'];
                if (players is! List) continue;

                String normalizeTeam(Object value) =>
                    value.toString().trim().toLowerCase();
                final teamKey = normalizeTeam(
                  data['teamId'] ??
                      data['id'] ??
                      data['teamName'] ??
                      registration.id,
                );
                final received =
                    goalsByTeam[teamKey] ??
                    goalsByTeam[normalizeTeam(data['teamName'] ?? '')] ??
                    goalsByTeam[normalizeTeam(registration.id)] ??
                    0;

                for (final rawPlayer in players) {
                  if (rawPlayer is! Map) continue;
                  final role =
                      '${rawPlayer['position'] ?? rawPlayer['role'] ?? rawPlayer['posicion'] ?? ''}'
                          .toLowerCase();
                  if (role.contains('arqu') || role.contains('port')) {
                    final name =
                        (rawPlayer['name'] ??
                                rawPlayer['nombre'] ??
                                rawPlayer['displayName'] ??
                                'Arquero')
                            .toString();
                    candidates[name] = received;
                  }
                }
              }

              if (candidates.isEmpty) return 'Sin datos';
              final best = candidates.entries.toList()
                ..sort((a, b) => a.value.compareTo(b.value));
              return '${best.first.key} · ${best.first.value} goles recibidos';
            }

            return Column(
              children: [
                if (tournament.shouldShowMaleScorers)
                  CompactActionCard(
                    icon: Icons.emoji_events_outlined,
                    title: 'Goleador masculino',
                    subtitle: 'Goles acumulados',
                    value: bestBy(false),
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
                    value: bestBy(true),
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

enum TournamentHighlightType { maleScorers, femaleScorers, goalkeepers }

class TournamentHighlightEntry {
  const TournamentHighlightEntry({
    required this.name,
    required this.value,
    this.team,
  });

  final String name;
  final int value;
  final String? team;
}

class TournamentHighlightsFullScreen extends StatelessWidget {
  const TournamentHighlightsFullScreen({
    required this.tournament,
    required this.type,
    super.key,
  });

  final Tournament tournament;
  final TournamentHighlightType type;

  String _text(Object? value) => value?.toString().trim() ?? '';

  String _gender(Map<String, dynamic> player) => _text(
    player['gender'] ?? player['genero'] ?? player['sex'],
  ).toLowerCase();

  String _playerName(Map<String, dynamic> player) => _text(
    player['name'] ??
        player['nombre'] ??
        player['displayName'] ??
        player['fullName'],
  );

  String _playerKey(Map<String, dynamic> player) => _text(
    player['id'] ?? player['uid'] ?? player['playerId'] ?? _playerName(player),
  );

  String _teamName(Map<String, dynamic> team, String fallback) {
    final value = _text(
      team['teamName'] ?? team['name'] ?? team['displayName'],
    );
    return value.isEmpty ? fallback : value;
  }

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

  Future<List<TournamentHighlightEntry>> _loadEntries() async {
    final ref = FirebaseFirestore.instance
        .collection('tournaments')
        .doc(tournament.id);
    final registrationSnapshot = await ref.collection('registrations').get();
    final matchSnapshot = await ref.collection('matches').get();
    final players = <String, Map<String, dynamic>>{};
    final playerTeams = <String, String>{};
    final teamGoalsAgainst = <String, int>{};
    final teamNames = <String, String>{};
    final entries = <String, int>{};

    String normalize(Object? value) => value.toString().trim().toLowerCase();

    List<String> teamIdentifiers(Object? raw) {
      if (raw is Map) {
        return [
          raw['id'],
          raw['teamId'],
          raw['registrationId'],
          raw['name'],
          raw['teamName'],
        ].where((v) => v != null && _text(v).isNotEmpty).map(_text).toList();
      }
      return _text(raw).isEmpty ? const [] : [_text(raw)];
    }

    for (final registration in registrationSnapshot.docs) {
      final data = registration.data();
      final status = data['status']?.toString().trim().toLowerCase();
      if (status != 'approved' && status != 'aprobada' && status != 'aprobado')
        continue;

      final name = _teamName(data, registration.id);
      final identifiers = {
        ...teamIdentifiers(registration.id),
        ...teamIdentifiers(data['teamId']),
        ...teamIdentifiers(data['id']),
        ...teamIdentifiers(data['teamName']),
        ...teamIdentifiers(data['team']),
      };
      for (final identifier in identifiers)
        teamNames[normalize(identifier)] = name;

      final rawPlayers = data['players'];
      if (rawPlayers is! List) continue;
      for (final raw in rawPlayers) {
        if (raw is! Map) continue;
        final player = Map<String, dynamic>.from(raw);
        final key = _playerKey(player);
        if (key.isEmpty) continue;
        players[key] = player;
        playerTeams[key] = name;
        if (type != TournamentHighlightType.goalkeepers) entries[key] = 0;
      }
    }

    for (final match in matchSnapshot.docs) {
      final data = match.data();
      final status = normalize(data['status']);
      if (!{
        'finished',
        'finalizado',
        'finalizada',
        'completed',
      }.contains(status))
        continue;
      if (!_isApprovedLineup(data)) continue;

      final homeIds = teamIdentifiers(
        data['homeTeamId'] ?? data['homeTeam'] ?? data['homeTeamName'],
      );
      final awayIds = teamIdentifiers(
        data['awayTeamId'] ?? data['awayTeam'] ?? data['awayTeamName'],
      );
      final homeKey = homeIds
          .map(normalize)
          .firstWhere(
            (id) => teamNames.containsKey(id),
            orElse: () => homeIds.isEmpty ? '' : normalize(homeIds.first),
          );
      final awayKey = awayIds
          .map(normalize)
          .firstWhere(
            (id) => teamNames.containsKey(id),
            orElse: () => awayIds.isEmpty ? '' : normalize(awayIds.first),
          );

      final homeGoals =
          (data['finalHomeScore'] as num?)?.toInt() ??
          int.tryParse(_text(data['finalHomeScore'] ?? data['homeScore'])) ??
          0;
      final awayGoals =
          (data['finalAwayScore'] as num?)?.toInt() ??
          int.tryParse(_text(data['finalAwayScore'] ?? data['awayScore'])) ??
          0;

      if (homeKey.isNotEmpty) {
        teamGoalsAgainst[homeKey] =
            (teamGoalsAgainst[homeKey] ?? 0) + awayGoals;
      }
      if (awayKey.isNotEmpty) {
        teamGoalsAgainst[awayKey] =
            (teamGoalsAgainst[awayKey] ?? 0) + homeGoals;
      }

      final rawEvents = data['finalEvents'] ?? data['events'];
      if (rawEvents is! List || type == TournamentHighlightType.goalkeepers)
        continue;
      for (final raw in rawEvents) {
        if (raw is! Map || _text(raw['type']).toLowerCase() != 'goal') continue;
        final key = _text(raw['player'] ?? raw['playerId'] ?? raw['uid']);
        final name = _text(raw['playerName'] ?? raw['name']);
        final matchingKey = players.keys.firstWhere(
          (candidate) =>
              candidate == key ||
              _text(
                    players[candidate]?['name'] ??
                        players[candidate]?['nombre'],
                  ) ==
                  name,
          orElse: () => '',
        );
        if (matchingKey.isNotEmpty)
          entries[matchingKey] = (entries[matchingKey] ?? 0) + 1;
      }
    }

    if (type == TournamentHighlightType.goalkeepers) {
      for (final entry in players.entries) {
        final role = _text(
          entry.value['position'] ??
              entry.value['role'] ??
              entry.value['posicion'],
        ).toLowerCase();
        if (!(role.contains('arqu') ||
            role.contains('port') ||
            role.contains('goalkeeper'))) {
          continue;
        }

        var receivedGoals = 0;
        for (final teamEntry in teamGoalsAgainst.entries) {
          if (teamNames[teamEntry.key] == playerTeams[entry.key]) {
            receivedGoals = teamEntry.value;
            break;
          }
        }
        entries[entry.key] = receivedGoals;
      }
    }

    final female = type == TournamentHighlightType.femaleScorers;
    return entries.entries
        .where((entry) {
          final gender = _gender(players[entry.key] ?? const {});
          if (type == TournamentHighlightType.goalkeepers) return true;
          if (gender.isEmpty) return true;
          return female
              ? gender.contains('fem') || gender.contains('muj')
              : gender.contains('masc') ||
                    gender.contains('hom') ||
                    gender == 'm';
        })
        .map(
          (entry) => TournamentHighlightEntry(
            name: _playerName(players[entry.key] ?? const {}),
            value: entry.value,
            team: playerTeams[entry.key],
          ),
        )
        .where((entry) => entry.name.isNotEmpty)
        .toList()
      ..sort(
        (a, b) => type == TournamentHighlightType.goalkeepers
            ? a.value.compareTo(b.value)
            : b.value.compareTo(a.value),
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
