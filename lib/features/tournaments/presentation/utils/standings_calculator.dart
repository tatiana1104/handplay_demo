import 'package:cloud_firestore/cloud_firestore.dart';

class StandingEntry {
  /// ES: Crea una fila final de la tabla de posiciones.
  /// EN: Creates a finalized row in the tournament standings table.
  const StandingEntry({required this.team, required this.played, required this.wins, required this.draws, required this.losses, required this.goalsFor, required this.goalsAgainst, required this.points});

  final String team;
  final int played;
  final int wins;
  final int draws;
  final int losses;
  final int goalsFor;
  final int goalsAgainst;
  final int points;

  /// ES: Devuelve los goles anotados menos los recibidos.
  /// EN: Returns scored goals minus conceded goals.
  int get goalDifference => goalsFor - goalsAgainst;
}

/// ES: Calcula posiciones a partir de inscripciones aprobadas y partidos terminados.
/// EN: Calculates standings from approved registrations and completed matches.
List<StandingEntry> calculateStandings({
  required List<QueryDocumentSnapshot<Map<String, dynamic>>> registrations,
  required List<QueryDocumentSnapshot<Map<String, dynamic>>> matches,
}) {
  final teams = <String, _MutableStanding>{};
  final aliases = <String, String>{};

  for (final registration in registrations) {
    final data = registration.data();
    final name = _teamName(data, registration.id);
    final entry = teams.putIfAbsent(registration.id, () => _MutableStanding(name));
    for (final alias in _identifiers(registration.id, data)) {
      aliases[_normalize(alias)] = registration.id;
    }
    if (entry.name.isEmpty) entry.name = name;
  }

  for (final match in matches) {
    final data = match.data();
    if (!_isFinished(data['status'])) continue;
    final home = _findTeam(data['homeTeamId'] ?? data['homeTeam'] ?? data['homeTeamName'], aliases);
    final away = _findTeam(data['awayTeamId'] ?? data['awayTeam'] ?? data['awayTeamName'], aliases);
    if (home == null || away == null || home == away) continue;

    final homeGoals = _number(data['finalHomeScore'] ?? data['homeScore'] ?? data['scoreHome'] ?? data['homeGoals']);
    final awayGoals = _number(data['finalAwayScore'] ?? data['awayScore'] ?? data['scoreAway'] ?? data['awayGoals']);
    final homeStats = teams[home];
    final awayStats = teams[away];
    if (homeStats == null || awayStats == null) continue;

    homeStats.played++;
    awayStats.played++;
    homeStats.goalsFor += homeGoals;
    homeStats.goalsAgainst += awayGoals;
    awayStats.goalsFor += awayGoals;
    awayStats.goalsAgainst += homeGoals;

    if (homeGoals == awayGoals) {
      homeStats.draws++;
      awayStats.draws++;
      homeStats.points++;
      awayStats.points++;
    } else if (homeGoals > awayGoals) {
      homeStats.wins++;
      homeStats.points += 3;
      awayStats.losses++;
    } else {
      awayStats.wins++;
      awayStats.points += 3;
      homeStats.losses++;
    }
  }

  final result = teams.values.map((team) => team.freeze()).toList();
  result.sort((a, b) {
    final points = b.points.compareTo(a.points);
    if (points != 0) return points;
    final difference = b.goalDifference.compareTo(a.goalDifference);
    if (difference != 0) return difference;
    final goals = b.goalsFor.compareTo(a.goalsFor);
    if (goals != 0) return goals;
    return a.team.toLowerCase().compareTo(b.team.toLowerCase());
  });
  return result;
}

class _MutableStanding {
  /// ES: Crea un acumulador de estadísticas para un equipo.
  /// EN: Creates an accumulator for one team's match statistics.
  _MutableStanding(this.name);
  String name;
  int played = 0;
  int wins = 0;
  int draws = 0;
  int losses = 0;
  int goalsFor = 0;
  int goalsAgainst = 0;
  int points = 0;

  /// ES: Convierte los acumulados en una fila inmutable de posiciones.
  /// EN: Freezes accumulated values into an immutable standings row.
  StandingEntry freeze() => StandingEntry(team: name, played: played, wins: wins, draws: draws, losses: losses, goalsFor: goalsFor, goalsAgainst: goalsAgainst, points: points);

  /// ES: Devuelve los goles anotados menos recibidos por el acumulador.
  /// EN: Returns scored goals minus conceded goals for the accumulator.
  int get goalDifference => goalsFor - goalsAgainst;
}

/// ES: Obtiene el nombre visible de los esquemas de inscripción compatibles.
/// EN: Resolves the display name stored by supported registration schemas.
String _teamName(Map<String, dynamic> data, String fallback) {
  final team = data['team'];
  if (team is Map) return (team['name'] ?? team['teamName'] ?? team['id'] ?? fallback).toString();
  return (data['teamName'] ?? data['name'] ?? (team is String ? team : fallback)).toString();
}

/// ES: Enumera IDs y nombres que identifican al equipo de una inscripción.
/// EN: Lists IDs and names that can refer to a registration's team.
Iterable<String> _identifiers(String registrationId, Map<String, dynamic> data) sync* {
  yield registrationId;
  for (final value in [data['id'], data['teamId'], data['registrationId'], data['uid'], data['teamUid'], data['teamName'], data['name']]) {
    if (value != null && value.toString().trim().isNotEmpty) yield value.toString();
  }
  final team = data['team'];
  if (team is Map) {
    for (final value in [team['id'], team['teamId'], team['name'], team['teamName']]) {
      if (value != null && value.toString().trim().isNotEmpty) yield value.toString();
    }
  } else if (team != null && team.toString().trim().isNotEmpty) {
    yield team.toString();
  }
}

/// ES: Resuelve el equipo de un partido a su ID usando alias.
/// EN: Resolves a match-side value to a registered team ID through aliases.
String? _findTeam(Object? raw, Map<String, String> aliases) {
  if (raw is Map) {
    for (final value in [raw['id'], raw['teamId'], raw['registrationId'], raw['uid'], raw['name'], raw['teamName']]) {
      final found = aliases[_normalize(value)];
      if (found != null) return found;
    }
    return null;
  }
  final value = raw?.toString() ?? '';
  return aliases[_normalize(value)];
}

/// ES: Normaliza IDs y nombres para comparar alias de forma consistente.
/// EN: Normalizes IDs and names for consistent alias comparisons.
String _normalize(Object? value) => value?.toString().trim().toLowerCase() ?? '';

/// ES: Convierte números de Firestore y usa cero si el dato falta o no es válido.
/// EN: Parses Firestore numbers and defaults missing or invalid values to zero.
int _number(Object? value) => value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;

/// ES: Reconoce los estados guardados que indican un partido terminado.
/// EN: Recognizes stored status values that indicate a completed match.
bool _isFinished(Object? value) => {'finished', 'finished_match', 'completed', 'complete', 'finalizado', 'finalizada'}.contains(_normalize(value));
