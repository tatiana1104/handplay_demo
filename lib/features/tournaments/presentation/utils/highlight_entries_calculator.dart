/// RF-19 / RF-20: qué tabla de estadísticas individuales se calcula.
enum TournamentHighlightType { maleScorers, femaleScorers, goalkeepers }

class TournamentHighlightEntry {
  const TournamentHighlightEntry({
    required this.name,
    required this.value,
    this.team,
  });

  final String name;

  /// Goles anotados (goleadores) o goles recibidos (valla menos vencida).
  final int value;
  final String? team;
}

/// Inscripción de un equipo: el id de su documento y sus datos. Se usa
/// este tipo simple (en vez de `QueryDocumentSnapshot`) para que la
/// lógica no dependa de Firestore y se pueda probar con datos de mano.
typedef HighlightRegistration = ({String id, Map<String, dynamic> data});

/// Calcula goleadores, goleadoras o valla menos vencida de un torneo.
///
/// Esta es la ÚNICA implementación: el resumen del torneo y la pantalla
/// de tabla completa la usan las dos. Antes cada una tenía su propia
/// copia de la lógica, y por eso los mismos errores aparecían (y había
/// que corregirlos) en dos lugares.
///
/// Errores que corrige respecto a la versión anterior:
///
/// 1. **Tocayos en equipos distintos.** Los jugadores se indexaban solo
///    por nombre a nivel de TODO el torneo, así que dos jugadores con el
///    mismo nombre en equipos diferentes sumaban sus goles juntos. Ahora
///    todo se indexa por "equipo::jugador" y el gol se busca únicamente
///    en la plantilla del equipo que anotó (el evento guarda
///    `team: 'home'|'away'`, ver `live_match_screen._recordPlayerEvent`).
/// 2. **Jugador sin género.** Antes, sin género cargado, el jugador
///    contaba para las DOS tablas (masculina y femenina). Ahora no entra
///    en ninguna. El género es obligatorio al inscribir (RF-05), así que
///    esto solo afecta datos viejos o incompletos.
/// 3. **Dos porteros en el mismo equipo.** En el resumen, el segundo
///    pisaba al primero en silencio. Ahora cada portero marcado en la
///    plantilla es una entrada propia; los dos muestran los goles
///    recibidos del equipo (con los datos actuales no se puede saber
///    cuántos atajó cada uno).
///
/// Reglas que se conservan tal cual: solo equipos con inscripción
/// aprobada, solo partidos finalizados con planilla aprobada, y los
/// goles se leen de `finalEvents` (o `events` si no existe).
List<TournamentHighlightEntry> computeHighlightEntries({
  required TournamentHighlightType type,
  required Iterable<HighlightRegistration> registrations,
  required Iterable<Map<String, dynamic>> matches,
}) {
  final isGoalkeepers = type == TournamentHighlightType.goalkeepers;

  // Cada equipo se identifica con una clave canónica (el id de su
  // inscripción). `teamKeyAliases` traduce cualquier otra forma en que un
  // partido pueda nombrarlo (homeTeamId, homeTeam, homeTeamName...).
  final teamKeyAliases = <String, String>{};
  final playersByTeam = <String, Map<String, Map<String, dynamic>>>{};
  final entries = <String, int>{};
  final entryPlayer = <String, Map<String, dynamic>>{};
  final entryTeamName = <String, String>{};

  for (final registration in registrations) {
    final data = registration.data;
    if (!_isApprovedStatus(data['status'])) continue;

    final teamKey = _normalize(registration.id);
    final teamName = _teamName(data, registration.id);
    for (final identifier in {
      ..._teamIdentifiers(registration.id),
      ..._teamIdentifiers(data['teamId']),
      ..._teamIdentifiers(data['id']),
      ..._teamIdentifiers(data['teamName']),
      ..._teamIdentifiers(data['team']),
    }) {
      teamKeyAliases[_normalize(identifier)] = teamKey;
    }

    final rawPlayers = data['players'];
    if (rawPlayers is! List) continue;
    final roster = <String, Map<String, dynamic>>{};
    for (final raw in rawPlayers) {
      if (raw is! Map) continue;
      final player = Map<String, dynamic>.from(raw);
      final localKey = _playerKey(player);
      if (localKey.isEmpty) continue;
      roster[localKey] = player;
      final compositeKey = '$teamKey::$localKey';
      entryPlayer[compositeKey] = player;
      entryTeamName[compositeKey] = teamName;
      if (!isGoalkeepers) entries[compositeKey] = 0;
    }
    playersByTeam[teamKey] = roster;
  }

  String resolveTeamKey(Object? raw) {
    final identifiers = _teamIdentifiers(raw);
    for (final identifier in identifiers) {
      final canonical = teamKeyAliases[_normalize(identifier)];
      if (canonical != null) return canonical;
    }
    return identifiers.isEmpty ? '' : _normalize(identifiers.first);
  }

  String? findInRoster(
    Map<String, Map<String, dynamic>>? roster,
    String eventKey,
    String eventName,
  ) {
    if (roster == null) return null;
    for (final entry in roster.entries) {
      if (entry.key == eventKey) return entry.key;
      if (eventName.isNotEmpty && _playerName(entry.value) == eventName) {
        return entry.key;
      }
    }
    return null;
  }

  final teamGoalsAgainst = <String, int>{};

  for (final match in matches) {
    final data = match;
    final status = _normalize(data['status']);
    if (!_finishedStatuses.contains(status)) continue;
    if (!_isApprovedLineup(data)) continue;

    final homeKey = resolveTeamKey(
      data['homeTeamId'] ?? data['homeTeam'] ?? data['homeTeamName'],
    );
    final awayKey = resolveTeamKey(
      data['awayTeamId'] ?? data['awayTeam'] ?? data['awayTeamName'],
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
      teamGoalsAgainst[homeKey] = (teamGoalsAgainst[homeKey] ?? 0) + awayGoals;
    }
    if (awayKey.isNotEmpty) {
      teamGoalsAgainst[awayKey] = (teamGoalsAgainst[awayKey] ?? 0) + homeGoals;
    }

    final rawEvents = data['finalEvents'] ?? data['events'];
    if (rawEvents is! List || isGoalkeepers) continue;

    for (final raw in rawEvents) {
      if (raw is! Map || _text(raw['type']).toLowerCase() != 'goal') continue;
      final eventKey = _text(raw['player'] ?? raw['playerId'] ?? raw['uid']);
      final eventName = _text(raw['playerName'] ?? raw['name']);

      String? scoringTeamKey;
      String? matchingKey;
      final side = _text(raw['team']).toLowerCase();
      if (side == 'home' || side == 'away') {
        scoringTeamKey = side == 'home' ? homeKey : awayKey;
        matchingKey = findInRoster(
          playersByTeam[scoringTeamKey],
          eventKey,
          eventName,
        );
      } else {
        // Evento sin equipo (datos viejos): solo se atribuye si el
        // jugador aparece en UNA de las dos plantillas. Si aparece en
        // las dos, es ambiguo y se omite en vez de adivinar.
        final inHome = findInRoster(playersByTeam[homeKey], eventKey, eventName);
        final inAway = findInRoster(playersByTeam[awayKey], eventKey, eventName);
        if (inHome != null && inAway == null) {
          scoringTeamKey = homeKey;
          matchingKey = inHome;
        } else if (inAway != null && inHome == null) {
          scoringTeamKey = awayKey;
          matchingKey = inAway;
        }
      }

      if (scoringTeamKey == null || matchingKey == null) continue;
      final compositeKey = '$scoringTeamKey::$matchingKey';
      entries[compositeKey] = (entries[compositeKey] ?? 0) + 1;
    }
  }

  if (isGoalkeepers) {
    for (final team in playersByTeam.entries) {
      final received = teamGoalsAgainst[team.key] ?? 0;
      for (final player in team.value.entries) {
        final role = _text(
          player.value['position'] ??
              player.value['role'] ??
              player.value['posicion'],
        ).toLowerCase();
        if (role.contains('arqu') ||
            role.contains('port') ||
            role.contains('goalkeeper')) {
          entries['${team.key}::${player.key}'] = received;
        }
      }
    }
  }

  final female = type == TournamentHighlightType.femaleScorers;
  final result = entries.entries
      .where((entry) {
        if (isGoalkeepers) return true;
        final gender = _gender(entryPlayer[entry.key] ?? const {});
        if (gender.isEmpty) return false;
        return female ? _isFemale(gender) : _isMale(gender);
      })
      .map(
        (entry) => TournamentHighlightEntry(
          name: _playerName(entryPlayer[entry.key] ?? const {}),
          value: entry.value,
          team: entryTeamName[entry.key],
        ),
      )
      .where((entry) => entry.name.isNotEmpty)
      .toList();

  result.sort(
    (a, b) =>
        isGoalkeepers ? a.value.compareTo(b.value) : b.value.compareTo(a.value),
  );
  return result;
}

const _finishedStatuses = {
  'finished',
  'finished_match',
  'completed',
  'complete',
  'finalizado',
  'finalizada',
};

bool _isFemale(String gender) => gender.contains('fem') || gender.contains('muj');

bool _isMale(String gender) =>
    gender.contains('masc') || gender.contains('hom') || gender == 'm';

String _text(Object? value) => value?.toString().trim() ?? '';

String _normalize(Object? value) => _text(value).toLowerCase();

String _gender(Map<String, dynamic> player) =>
    _normalize(player['gender'] ?? player['genero'] ?? player['sex']);

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
  final value = _text(team['teamName'] ?? team['name'] ?? team['displayName']);
  return value.isEmpty ? fallback : value;
}

bool _isApprovedStatus(Object? value) {
  final normalized = _normalize(value);
  return normalized == 'approved' ||
      normalized == 'aprobada' ||
      normalized == 'aprobado';
}

bool _isApprovedLineup(Map<String, dynamic> data) => _isApprovedStatus(
  data['lineupStatus'] ??
      data['rosterStatus'] ??
      data['planillaStatus'] ??
      data['lineup_status'],
);

List<String> _teamIdentifiers(Object? raw) {
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
