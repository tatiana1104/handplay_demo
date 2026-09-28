import 'package:cloud_firestore/cloud_firestore.dart';

/// Cálculos de estadísticas por equipo y por jugador a partir de los
/// documentos de `registrations` y `matches` de un torneo.
///
/// Los eventos del planillero se guardan como
/// `{type, player: '<numero>-<nombre>', playerName, team: 'home'|'away'}`.

typedef FirestoreDocs = List<QueryDocumentSnapshot<Map<String, dynamic>>>;

const _finishedStatuses = {'finished', 'finished_match', 'completed', 'complete', 'finalizado', 'finalizada'};

String normalizeKey(Object? value) => value?.toString().trim().toLowerCase() ?? '';

int _number(Object? value) => value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;

DateTime? _date(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return DateTime.tryParse(value?.toString() ?? '');
}

bool isFinishedMatch(Map<String, dynamic> data) => _finishedStatuses.contains(normalizeKey(data['status']));

/// Convierte `libre|mixto` en `Libre · Mixto`.
String formatCategory(Object? raw) {
  final value = raw?.toString().trim() ?? '';
  if (value.isEmpty) return 'Categoría no registrada';
  return value
      .split('|')
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .map((part) => part[0].toUpperCase() + part.substring(1))
      .join(' · ');
}

String capitalize(String value) => value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);

enum MatchOutcome { win, draw, loss, pending }

class TeamMatchSummary {
  const TeamMatchSummary({
    required this.matchId,
    required this.opponent,
    required this.isHome,
    required this.date,
    required this.goalsFor,
    required this.goalsAgainst,
    required this.finished,
    required this.events,
  });

  final String matchId;
  final String opponent;
  final bool isHome;
  final DateTime? date;
  final int goalsFor;
  final int goalsAgainst;
  final bool finished;

  /// Solo los eventos de este equipo.
  final List<Map<String, dynamic>> events;

  MatchOutcome get outcome {
    if (!finished) return MatchOutcome.pending;
    if (goalsFor > goalsAgainst) return MatchOutcome.win;
    if (goalsFor == goalsAgainst) return MatchOutcome.draw;
    return MatchOutcome.loss;
  }
}

class PlayerMatchLine {
  const PlayerMatchLine({required this.match, required this.goals, required this.yellowCards, required this.redCards, required this.exclusions});
  final TeamMatchSummary match;
  final int goals;
  final int yellowCards;
  final int redCards;
  final int exclusions;
}

class PlayerStats {
  const PlayerStats({required this.history});

  final List<PlayerMatchLine> history;

  int get matchesPlayed => history.length;
  int get goals => history.fold(0, (sum, line) => sum + line.goals);
  int get yellowCards => history.fold(0, (sum, line) => sum + line.yellowCards);
  int get redCards => history.fold(0, (sum, line) => sum + line.redCards);
  int get exclusions => history.fold(0, (sum, line) => sum + line.exclusions);
  String get average => matchesPlayed == 0 ? '0.0' : (goals / matchesPlayed).toStringAsFixed(1);
}

Set<String> registrationIdentifiers(String? registrationId, Map<String, dynamic> data) {
  final team = data['team'];
  return {
    registrationId,
    data['id'],
    data['teamId'],
    data['registrationId'],
    data['teamUid'],
    data['uid'],
    data['teamName'],
    data['name'],
    if (team is Map) ...[team['id'], team['teamId'], team['name'], team['teamName']] else team,
  }.map(normalizeKey).where((value) => value.isNotEmpty).toSet();
}

Set<String> _matchSideIdentifiers(Map<String, dynamic> data, String side) {
  final raw = data['${side}TeamId'] ?? data['${side}Team'];
  return {
    if (raw is Map) ...[raw['id'], raw['teamId'], raw['registrationId'], raw['name'], raw['teamName']] else raw,
    data['${side}TeamName'],
  }.map(normalizeKey).where((value) => value.isNotEmpty).toSet();
}

String _sideName(Map<String, dynamic> data, String side) {
  final name = data['${side}TeamName']?.toString().trim();
  if (name != null && name.isNotEmpty) return name;
  final raw = data['${side}Team'];
  if (raw is Map) return (raw['name'] ?? raw['teamName'] ?? 'Rival').toString();
  return raw?.toString().trim().isNotEmpty == true ? raw.toString() : 'Rival por definir';
}

/// Partidos del equipo (programados y finalizados), del más reciente al más antiguo.
List<TeamMatchSummary> teamMatches({required Set<String> identifiers, required FirestoreDocs matches}) {
  final result = <TeamMatchSummary>[];
  for (final doc in matches) {
    final data = doc.data();
    final isHome = _matchSideIdentifiers(data, 'home').any(identifiers.contains);
    final isAway = !isHome && _matchSideIdentifiers(data, 'away').any(identifiers.contains);
    if (!isHome && !isAway) continue;

    final finished = isFinishedMatch(data);
    final homeScore = _number(finished ? (data['finalHomeScore'] ?? data['homeScore']) : data['homeScore']);
    final awayScore = _number(finished ? (data['finalAwayScore'] ?? data['awayScore']) : data['awayScore']);
    final side = isHome ? 'home' : 'away';
    final rawEvents = data['finalEvents'] ?? data['events'];
    final events = rawEvents is List
        ? rawEvents
            .whereType<Map>()
            .map((event) => Map<String, dynamic>.from(event))
            .where((event) => event['team'] == null || event['team'] == side)
            .toList()
        : <Map<String, dynamic>>[];

    result.add(TeamMatchSummary(
      matchId: doc.id,
      opponent: _sideName(data, isHome ? 'away' : 'home'),
      isHome: isHome,
      date: _date(data['scheduledAt'] ?? data['date'] ?? data['fecha']),
      goalsFor: isHome ? homeScore : awayScore,
      goalsAgainst: isHome ? awayScore : homeScore,
      finished: finished,
      events: events,
    ));
  }
  result.sort((a, b) {
    if (a.date == null && b.date == null) return 0;
    if (a.date == null) return 1;
    if (b.date == null) return -1;
    return b.date!.compareTo(a.date!);
  });
  return result;
}

Set<String> playerIdentifiers(Map player) {
  final name = (player['name'] ?? player['nombre'] ?? player['fullName'] ?? '').toString().trim();
  final number = player['number']?.toString().trim() ?? '';
  return {
    player['id'],
    player['uid'],
    player['playerId'],
    name,
    if (number.isNotEmpty && name.isNotEmpty) '$number-$name',
  }.map(normalizeKey).where((value) => value.isNotEmpty).toSet();
}

/// Estadísticas del jugador en los partidos finalizados de su equipo.
PlayerStats playerStats({required Map player, required List<TeamMatchSummary> teamMatches}) {
  final ids = playerIdentifiers(player);
  bool belongs(Map<String, dynamic> event) =>
      ids.contains(normalizeKey(event['player'])) || ids.contains(normalizeKey(event['playerName'])) || ids.contains(normalizeKey(event['playerId']));

  final history = <PlayerMatchLine>[];
  for (final match in teamMatches.where((match) => match.finished)) {
    final own = match.events.where(belongs).toList();
    int count(Set<String> types) => own.where((event) => types.contains(normalizeKey(event['type']))).length;
    history.add(PlayerMatchLine(
      match: match,
      goals: count({'goal', 'gol'}),
      yellowCards: count({'yellowcard', 'yellow', 'amarilla'}),
      redCards: count({'redcard', 'red', 'roja'}),
      exclusions: count({'exclusion', 'suspension', 'twominutes'}),
    ));
  }
  return PlayerStats(history: history);
}
