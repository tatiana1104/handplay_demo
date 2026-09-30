import 'package:cloud_firestore/cloud_firestore.dart';

/// Cálculos de estadísticas por equipo y por jugador a partir de los
/// documentos de `registrations` y `matches` de un torneo.
///
/// Los eventos del planillero se guardan como
/// `{type, player: '<numero>-<nombre>', playerName, team: 'home'|'away'}`.

typedef FirestoreDocs = List<QueryDocumentSnapshot<Map<String, dynamic>>>;

const _finishedStatuses = {'finished', 'finished_match', 'completed', 'complete', 'finalizado', 'finalizada'};

/// ES: Normaliza nombres, IDs y estados para compararlos sin distinguir mayúsculas.
/// EN: Normalizes names, IDs, and statuses for case-insensitive comparisons.
String normalizeKey(Object? value) => value?.toString().trim().toLowerCase() ?? '';

/// ES: Convierte un número Firestore y devuelve cero si falta o no es válido.
/// EN: Parses a Firestore number, returning zero when missing or invalid.
int _number(Object? value) => value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;

/// ES: Convierte timestamps, fechas o cadenas válidas a una fecha Dart.
/// EN: Converts Firestore timestamps, dates, or parseable strings to a Dart date.
DateTime? _date(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return DateTime.tryParse(value?.toString() ?? '');
}

/// ES: Comprueba si el documento indica un estado reconocido de partido terminado.
/// EN: Checks whether the match document has a recognized completed status.
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

/// ES: Convierte en mayúscula la primera letra de una cadena no vacía.
/// EN: Capitalizes the first character of a non-empty string.
String capitalize(String value) => value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);

/// ES: Resultados posibles de un partido desde la perspectiva del equipo.
/// EN: Possible outcomes for a team's perspective on a match.
enum MatchOutcome { win, draw, loss, pending }

/// ES: Resultado y eventos de un partido desde la perspectiva de un equipo.
/// EN: Match result and events viewed from one team's perspective.
class TeamMatchSummary {
  /// ES: Crea el resumen de un partido programado o finalizado.
  /// EN: Creates a summary for a scheduled or completed match.
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

  /// ES: Determina el resultado según el estado y el marcador del equipo.
  /// EN: Derives the outcome from completion state and the team's score.
  MatchOutcome get outcome {
    if (!finished) return MatchOutcome.pending;
    if (goalsFor > goalsAgainst) return MatchOutcome.win;
    if (goalsFor == goalsAgainst) return MatchOutcome.draw;
    return MatchOutcome.loss;
  }
}

/// ES: Estadísticas de un jugador registradas en un partido.
/// EN: Player statistics recorded for a single match.
class PlayerMatchLine {
  /// ES: Crea el resumen de eventos del jugador para un partido.
  /// EN: Creates the player's event totals for one match.
  const PlayerMatchLine({required this.match, required this.goals, required this.yellowCards, required this.redCards, required this.exclusions});
  final TeamMatchSummary match;
  final int goals;
  final int yellowCards;
  final int redCards;
  final int exclusions;
}

/// ES: Estadísticas agregadas e historial de partidos de un jugador.
/// EN: Aggregated statistics and match history for a player.
class PlayerStats {
  /// ES: Crea estadísticas a partir del historial por partido.
  /// EN: Creates statistics from the player's per-match history.
  const PlayerStats({required this.history});

  final List<PlayerMatchLine> history;

  /// ES: Cuenta los partidos incluidos en el historial del jugador.
  /// EN: Counts match entries in the player's history.
  int get matchesPlayed => history.length;

  /// ES: Suma los goles del jugador en su historial.
  /// EN: Totals the player's goals across the history.
  int get goals => history.fold(0, (sum, line) => sum + line.goals);

  /// ES: Suma las tarjetas amarillas del jugador.
  /// EN: Totals the player's yellow cards.
  int get yellowCards => history.fold(0, (sum, line) => sum + line.yellowCards);

  /// ES: Suma las tarjetas rojas del jugador.
  /// EN: Totals the player's red cards.
  int get redCards => history.fold(0, (sum, line) => sum + line.redCards);

  /// ES: Suma las exclusiones del jugador.
  /// EN: Totals the player's exclusions.
  int get exclusions => history.fold(0, (sum, line) => sum + line.exclusions);

  /// ES: Calcula el promedio de goles por partido con un decimal.
  /// EN: Calculates average goals per match, formatted to one decimal place.
  String get average => matchesPlayed == 0 ? '0.0' : (goals / matchesPlayed).toStringAsFixed(1);
}

/// ES: Reúne los identificadores admitidos para asociar inscripciones a equipos.
/// EN: Collects supported identifiers for matching registrations to teams.
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

/// ES: Devuelve IDs y nombres guardados para el local o visitante.
/// EN: Returns IDs and names stored for a home or away match side.
Set<String> _matchSideIdentifiers(Map<String, dynamic> data, String side) {
  final raw = data['${side}TeamId'] ?? data['${side}Team'];
  return {
    if (raw is Map) ...[raw['id'], raw['teamId'], raw['registrationId'], raw['name'], raw['teamName']] else raw,
    data['${side}TeamName'],
  }.map(normalizeKey).where((value) => value.isNotEmpty).toSet();
}

/// ES: Obtiene el nombre visible del rival desde los campos del partido.
/// EN: Resolves the visible opponent name from the match's supported fields.
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

/// ES: Reúne IDs, nombres y combinaciones de camiseta/nombre para identificar jugadores.
/// EN: Collects IDs, names, and shirt-number/name pairs to identify players.
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
  // ES: Admite identificadores de eventos antiguos y campos actuales.
  // EN: Matches legacy event identifiers and current player fields.
  bool belongs(Map<String, dynamic> event) =>
      ids.contains(normalizeKey(event['player'])) || ids.contains(normalizeKey(event['playerName'])) || ids.contains(normalizeKey(event['playerId']));

  final history = <PlayerMatchLine>[];
  for (final match in teamMatches.where((match) => match.finished)) {
    final own = match.events.where(belongs).toList();
    // ES: Cuenta solo los tipos de evento de la estadística solicitada.
    // EN: Counts only event types belonging to the requested statistic.
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
