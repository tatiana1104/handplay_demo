import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../../shared/widgets/app_bottom_navigation_bar.dart';

/// ES: Vista del partido en vivo, su marcador y planilla digital.
/// EN: Live match view with its score and digital score sheet.
class LiveMatchScreen extends StatefulWidget {
  /// ES: Crea la pantalla con el ID y los datos iniciales del partido.
  /// EN: Creates the screen with the match ID and initial match data.
  const LiveMatchScreen({super.key, required this.matchId, required this.match});
  final String matchId;
  final Map<String, dynamic> match;

  /// ES: Crea el estado que controla cronómetros, eventos y marcador.
  /// EN: Creates the state that manages timers, events, and score.
  @override
  State<LiveMatchScreen> createState() => _LiveMatchScreenState();
}

class _LiveMatchScreenState extends State<LiveMatchScreen> {
  late final Map<String, dynamic> _match = Map<String, dynamic>.from(widget.match);
  final Map<String, String> _officialNames = {};
  final Map<String, String> _officialEmails = {};
  bool _showOfficials = true;
  Timer? _timer;
  Timer? _suspensionTimer;
  Timer? _timeoutTimer;
  int _elapsedSeconds = 0;
  int _timeoutRemaining = 0;
  String? _timeoutOwner;
  final List<Map<String, dynamic>> _activeSuspensions = [];
  bool _isPaused = true;
  String? _selectedRoster;

  /// ES: Indica si la alineación ya fue aprobada y no puede editarse.
  /// EN: Indicates whether the lineup has been approved and locked.
  bool get _isRosterLocked => _match['lineupStatus']?.toString().toLowerCase() == 'approved';

  /// ES: Aprueba la alineación si el usuario puede usar la planilla.
  /// EN: Approves the lineup when the user can operate the score sheet.
  Future<void> _approveRoster() async {
    if (!_canUseScoreSheet || _isRosterLocked) return;
    await _saveMatch({
      'lineupStatus': 'approved',
      'lineupApprovedAt': FieldValue.serverTimestamp(),
      'lineupApprovedBy': _currentUid,
      'lineupApprovedByName': _currentEmail,
    });
  }

  /// ES: Restaura el cronómetro y carga nombres de equipos y oficiales.
  /// EN: Restores the timer and loads team and official names.
  @override
  void initState() {
    super.initState();
    _elapsedSeconds = (_match['elapsedSeconds'] as num?)?.toInt() ?? 0;
    _isPaused = !_isLiveStatus(_match['status']?.toString());
    if (_isLiveStatus(_match['status']?.toString())) _startLocalTimer();
    _loadOfficialNames();
    _loadTeamNames();
  }

  /// ES: Busca inscripciones aprobadas para resolver nombres de los equipos.
  /// EN: Loads approved registrations to resolve team names.
  Future<void> _loadTeamNames() async {
    final tournamentId = _match['tournamentId']?.toString();
    if (tournamentId == null || tournamentId.isEmpty) return;
    final snapshot = await FirebaseFirestore.instance.collection('tournaments').doc(tournamentId).collection('registrations').where('status', isEqualTo: 'approved').get();
    final registrations = snapshot.docs.map((doc) => <String, dynamic>{...doc.data(), 'documentId': doc.id}).toList();
    for (final side in ['home', 'away']) {
      final id = _match['${side}Team']?.toString();
      final registration = registrations.firstWhere((item) => [item['documentId'], item['id'], item['registrationId'], item['teamId'], item['teamUid'], item['uid']].map((value) => value?.toString()).contains(id), orElse: () => <String, dynamic>{});
      final name = registration['teamName'] ?? registration['name'] ?? registration['clubName'] ?? registration['team'];
      if (name != null && name.toString().trim().isNotEmpty && mounted) {
        setState(() => _match['${side}TeamName'] = name.toString().trim());
      }
    }
  }

  /// ES: Carga nombres y correos de los oficiales asignados al partido.
  /// EN: Loads names and emails for the officials assigned to the match.
  Future<void> _loadOfficialNames() async {
    final ids = ['refereeOne', 'refereeTwo', 'timekeeper', 'scorer']
        .map((key) => _match[key]?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet();
    for (final id in ids) {
      final snapshot = await FirebaseFirestore.instance.collection('users').doc(id).get();
      final data = snapshot.data();
      final name = data?['displayName']?.toString() ?? data?['nombre']?.toString();
      final email = (data?['email'] ?? data?['correo'])?.toString().trim().toLowerCase();
      if (!mounted) return;
      setState(() {
        if (name != null && name.trim().isNotEmpty) _officialNames[id] = name.trim();
        if (email != null && email.isNotEmpty) _officialEmails[id] = email;
      });
    }
  }

  /// ES: Obtiene el nombre del oficial o un texto alternativo.
  /// EN: Gets an official's display name or a fallback label.
  String _officialDisplayName(String key) {
    final value = _match[key]?.toString();
    if (value == null || value.isEmpty) return 'Sin asignar';
    return _match['${key}Name']?.toString() ?? _officialNames[value] ?? 'Sin nombre';
  }

  /// ES: Comprueba si el usuario autenticado tiene rol de árbitro.
  /// EN: Checks whether the authenticated user has the referee role.
  bool get _isReferee {
    final state = context.read<AuthBloc>().state;
    if (state is! AuthAuthenticated) return false;
    return state.user.roles
        .map((role) => role.trim().toLowerCase())
        .any((role) => role == 'arbitro' || role == 'árbitro' || role == 'referee');
  }

  /// ES: Devuelve el UID del usuario autenticado, si existe.
  /// EN: Returns the authenticated user's UID, when available.
  String? get _currentUid {
    final state = context.read<AuthBloc>().state;
    return state is AuthAuthenticated ? state.user.uid : null;
  }

  /// ES: Devuelve el correo normalizado del usuario autenticado.
  /// EN: Returns the authenticated user's normalized email.
  String? get _currentEmail {
    final state = context.read<AuthBloc>().state;
    return state is AuthAuthenticated ? state.user.email?.trim().toLowerCase() : null;
  }

  /// Un oficial puede tener varios documentos en `users` (cuenta de login y
  /// registro manual), así que se compara contra todos sus ids y su correo.
  /// EN: Checks all account aliases and email because one official may have multiple user documents.
  bool _isAssignedAs(String key) {
    final uid = _currentUid;
    if (uid == null) return false;
    final aliases = {
      _match[key]?.toString(),
      ...((_match['${key}Ids'] as List?) ?? const []).map((id) => id.toString()),
    };
    if (aliases.contains(uid)) return true;
    final email = _currentEmail;
    if (email == null || email.isEmpty) return false;
    final assignedEmail = (_match['${key}Email'] ?? _officialEmails[_match[key]?.toString()])?.toString().trim().toLowerCase();
    return assignedEmail == email;
  }

  /// ES: Permisos de operación según el rol asignado en la mesa.
  /// EN: Score-sheet permissions based on the assigned table role.
  bool get _isTimekeeper => _isAssignedAs('timekeeper');
  bool get _isScorer => _isAssignedAs('scorer');
  bool get _canOperate => _isTimekeeper || _isScorer;
  bool get _canUseScoreSheet => _isTimekeeper || _isScorer;

  /// ES: Cancela los cronómetros antes de destruir la pantalla.
  /// EN: Cancels timers before disposing the screen.
  @override
  void dispose() {
    _timer?.cancel();
    _suspensionTimer?.cancel();
    _timeoutTimer?.cancel();
    super.dispose();
  }

  /// ES: Inicia el cronómetro local que actualiza el tiempo transcurrido.
  /// EN: Starts the local timer that updates elapsed match time.
  void _startLocalTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _isPaused) return;
      setState(() => _elapsedSeconds++);
    });
  }

  /// ES: Permite al cronometrador iniciar o reanudar un tiempo muerto.
  /// EN: Lets the timekeeper start or resume a timeout.
  Future<void> _handleTimeout() async {
    if (!_isTimekeeper) return;
    if (_isPaused && _timeoutOwner == 'arbitros') {
      await _toggleTimer();
      return;
    }
    final owner = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Tiempo muerto'),
        content: const Text('¿Quién solicita el tiempo muerto?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, 'arbitros'), child: const Text('Árbitros')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, 'local'), child: Text(_teamName('homeTeamName', 'homeTeam'))),
          TextButton(onPressed: () => Navigator.pop(dialogContext, 'visitante'), child: Text(_teamName('awayTeamName', 'awayTeam'))),
        ],
      ),
    );
    if (owner == null) return;
    _timer?.cancel();
    _timeoutOwner = owner;
    _timeoutRemaining = owner == 'arbitros' ? 0 : 60;
    setState(() => _isPaused = true);
    final eventData = {
      'type': 'timeout',
      'owner': owner,
      'description': owner == 'arbitros' ? 'Tiempo muerto solicitado por los árbitros' : 'Tiempo muerto de ${owner == 'local' ? _teamName('homeTeamName', 'homeTeam') : _teamName('awayTeamName', 'awayTeam')}',
      'period': _match['period'] ?? 1,
      'elapsedSeconds': _elapsedSeconds,
      'createdAt': DateTime.now().toIso8601String(),
    };
    await _saveMatch({'status': 'tiempo_muerto', 'timeoutOwner': owner, 'timeoutRemaining': _timeoutRemaining, 'events': FieldValue.arrayUnion([eventData])});
    if (owner != 'arbitros') _startTeamTimeoutCountdown();
  }

  /// ES: Cuenta el tiempo muerto del equipo y reanuda el partido al terminar.
  /// EN: Counts down a team timeout and resumes play when it expires.
  void _startTeamTimeoutCountdown() {
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!mounted) return;
      if (_timeoutRemaining <= 1) {
        _timeoutTimer?.cancel();
        setState(() { _timeoutRemaining = 0; _timeoutOwner = null; _isPaused = false; });
        _startLocalTimer();
        await _saveMatch({'status': 'en_curso', 'timeoutRemaining': 0, 'timeoutOwner': null});
      } else {
        setState(() => _timeoutRemaining--);
      }
    });
  }

  /// ES: Pausa o reanuda el cronómetro y sincroniza el estado en Firestore.
  /// EN: Pauses or resumes the timer and syncs the match state to Firestore.
  Future<void> _toggleTimer() async {
    if (!_isTimekeeper) return;
    final shouldPause = !_isPaused;
    setState(() => _isPaused = shouldPause);
    if (shouldPause) {
      _timer?.cancel();
    } else {
      _startLocalTimer();
    }
    await _saveMatch({
      'status': shouldPause ? 'paused' : 'en_curso',
      'elapsedSeconds': _elapsedSeconds,
    });
  }

  /// ES: Guarda cambios del partido y actualiza la copia local.
  /// EN: Saves match changes and updates the local copy.
  Future<void> _saveMatch(Map<String, dynamic> data) async {
    await FirebaseFirestore.instance.collection('tournaments').doc(_match['tournamentId']).collection('matches').doc(widget.matchId).update(data);
    if (!mounted) return;
    final localData = <String, dynamic>{
      for (final entry in data.entries)
        if (entry.value is! FieldValue) entry.key: entry.value,
    };
    setState(() => _match.addAll(localData));
  }

  /// ES: Inicia el partido y persiste su primer estado en curso.
  /// EN: Starts the match and persists its first live state.
  Future<void> _startMatch() async {
    _elapsedSeconds = (_match['elapsedSeconds'] as num?)?.toInt() ?? 0;
    setState(() {
      _isPaused = false;
      _match['status'] = 'en_curso';
    });
    _startLocalTimer();
    await _saveMatch({
      'status': 'en_curso',
      'startedAt': FieldValue.serverTimestamp(),
      'period': _match['period'] ?? 1,
      'elapsedSeconds': _elapsedSeconds,
    });
  }

  /// ES: Cambia el período y reinicia el cronómetro en pausa.
  /// EN: Changes the period and resets the timer in a paused state.
  Future<void> _changePeriod(int period) async {
    if (!_isTimekeeper) return;
    await _saveMatch({'period': period, 'elapsedSeconds': 0, 'status': 'paused'});
    _timer?.cancel();
    setState(() {
      _elapsedSeconds = 0;
      _isPaused = true;
    });
  }

  /// ES: Inicia un período y guarda su tiempo y estado.
  /// EN: Starts a period and saves its time and status.
  Future<void> _startPeriod(int period) async {
    if (!_isTimekeeper) return;
    _timer?.cancel();
    _elapsedSeconds = 0;
    _isPaused = false;
    _match['period'] = period;
    _match['elapsedSeconds'] = 0;
    _match['status'] = 'en_curso';
    if (mounted) setState(() {});
    _startLocalTimer();
    await _saveMatch({
      'period': period,
      'elapsedSeconds': 0,
      'status': 'en_curso',
      'finishedAt': null,
      'periodStartedAt': FieldValue.serverTimestamp(),
      'startedAt': FieldValue.serverTimestamp(),
    });
  }

  /// ES: Reinicia el partido para comenzar el segundo período.
  /// EN: Resets the match to begin the second period.
  Future<void> _resetToSecondPeriod() => _startPeriod(2);

  /// ES: Confirma con el usuario antes de finalizar el encuentro.
  /// EN: Confirms with the user before ending the match.
  Future<void> _confirmFinishMatch() async {
    if (!_isTimekeeper || _match['status'] == 'finished') return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Finalizar partido'),
        content: const Text('¿Deseas guardar el marcador y finalizar este partido?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Finalizar')),
        ],
      ),
    );
    if (confirmed == true) await _finishMatch();
  }

  /// ES: Permite finalizar el partido o avanzar a un período adicional.
  /// EN: Lets the timekeeper finish the match or advance to another period.
  Future<void> _handlePeriodEnd() async {
    if (!_isTimekeeper) return;
    final shouldContinue = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Terminar período 2'),
        content: const Text('¿Deseas terminar el partido o pasar al período 3?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Pasar al período 3')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Terminar partido'),
          ),
        ],
      ),
    );
    if (shouldContinue == null) return;
    if (shouldContinue) {
      await _finishMatch();
    } else {
      await _startPeriod(3);
    }
  }

  /// ES: Actualiza puntos y goles de ambos equipos en una transacción.
  /// EN: Updates both teams' points and goals in one transaction.
  Future<void> _updateTournamentStandings(int homeScore, int awayScore) async {
    final tournamentId = _match['tournamentId']?.toString();
    /// ES: Extrae un identificador de equipo desde texto o mapa.
    /// EN: Extracts a team identifier from a string or map.
    String? identifierFor(Object? value) {
      if (value is Map) {
        for (final key in ['id', 'teamId', 'registrationId', 'uid', 'name', 'teamName']) {
          final candidate = value[key];
          if (candidate != null && candidate.toString().trim().isNotEmpty) return candidate.toString().trim();
        }
      }
      final text = value?.toString().trim();
      return text == null || text.isEmpty ? null : text;
    }
    final homeIdentifier = identifierFor(_match['homeTeamId'] ?? _match['homeTeam'] ?? _match['homeTeamName']);
    final awayIdentifier = identifierFor(_match['awayTeamId'] ?? _match['awayTeam'] ?? _match['awayTeamName']);
    if (tournamentId == null || homeIdentifier == null || awayIdentifier == null) return;
    final registrations = await FirebaseFirestore.instance.collection('tournaments').doc(tournamentId).collection('registrations').get();
    /// ES: Busca la inscripción que corresponde a un identificador de equipo.
    /// EN: Finds the registration matching a team identifier.
    QueryDocumentSnapshot<Map<String, dynamic>>? findRegistration(String identifier) {
      for (final doc in registrations.docs) {
        final data = doc.data();
        final identifiers = [doc.id, data['id'], data['registrationId'], data['teamId'], data['teamUid'], data['uid'], data['teamName'], data['name']].whereType<Object>().map((value) => value.toString().trim()).toSet();
        if (identifiers.contains(identifier)) return doc;
      }
      return null;
    }
    final homeDoc = findRegistration(homeIdentifier);
    final awayDoc = findRegistration(awayIdentifier);
    if (homeDoc == null || awayDoc == null || homeDoc.id == awayDoc.id) return;
    final homeRef = homeDoc.reference;
    final awayRef = awayDoc.reference;
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final home = (await transaction.get(homeRef)).data() ?? <String, dynamic>{};
      final away = (await transaction.get(awayRef)).data() ?? <String, dynamic>{};
      final homeWin = homeScore > awayScore;
      final awayWin = awayScore > homeScore;
      /// ES: Calcula los acumulados del equipo tras este resultado.
      /// EN: Calculates a team's cumulative statistics after this result.
      Map<String, dynamic> stats(Map<String, dynamic> current, bool win, bool draw) => {
        'points': ((current['points'] as num?)?.toInt() ?? 0) + (win ? 3 : draw ? 1 : 0),
        'played': ((current['played'] as num?)?.toInt() ?? 0) + 1,
        'wins': ((current['wins'] as num?)?.toInt() ?? 0) + (win ? 1 : 0),
        'draws': ((current['draws'] as num?)?.toInt() ?? 0) + (draw ? 1 : 0),
        'losses': ((current['losses'] as num?)?.toInt() ?? 0) + ((!win && !draw) ? 1 : 0),
        'goalsFor': ((current['goalsFor'] as num?)?.toInt() ?? 0),
      };
      final draw = homeScore == awayScore;
      final homeStats = stats(home, homeWin, draw);
      final awayStats = stats(away, awayWin, draw);
      homeStats['goalsFor'] = ((home['goalsFor'] as num?)?.toInt() ?? 0) + homeScore;
      homeStats['goalsAgainst'] = ((home['goalsAgainst'] as num?)?.toInt() ?? 0) + awayScore;
      awayStats['goalsFor'] = ((away['goalsFor'] as num?)?.toInt() ?? 0) + awayScore;
      awayStats['goalsAgainst'] = ((away['goalsAgainst'] as num?)?.toInt() ?? 0) + homeScore;
      /// ES: Mantiene alias cortos para compatibilidad con otros lectores.
      /// EN: Keeps short aliases for compatibility with existing readers.
      void addAliases(Map<String, dynamic> stats) {
        stats['pts'] = stats['points'];
        stats['pj'] = stats['played'];
        stats['pg'] = stats['wins'];
        stats['pe'] = stats['draws'];
        stats['pp'] = stats['losses'];
        stats['gf'] = stats['goalsFor'];
        stats['gc'] = stats['goalsAgainst'];
      }
      addAliases(homeStats);
      addAliases(awayStats);
      transaction.update(homeRef, homeStats);
      transaction.update(awayRef, awayStats);
    });
  }

  /// ES: Calcula posiciones y guarda el marcador final y los eventos.
  /// EN: Updates standings and saves the final score and match events.
  Future<void> _finishMatch() async {
    if (!_isTimekeeper || _match['status'] == 'finished') return;
    _timer?.cancel();
    final finalHomeScore = (_match['homeScore'] as num?)?.toInt() ?? 0;
    final finalAwayScore = (_match['awayScore'] as num?)?.toInt() ?? 0;
    try {
      await _updateTournamentStandings(finalHomeScore, finalAwayScore);
    } catch (_) {
      // ES: El partido debe finalizar aunque no se actualice la tabla.
      // EN: The match must finish even if standings cannot be updated.
    }
    await _saveMatch({
      'status': 'finished',
      'elapsedSeconds': _elapsedSeconds,
      'finishedAt': FieldValue.serverTimestamp(),
      'finalHomeScore': (_match['homeScore'] as num?)?.toInt() ?? 0,
      'finalAwayScore': (_match['awayScore'] as num?)?.toInt() ?? 0,
      'finalPeriod': (_match['period'] as num?)?.toInt() ?? 1,
      'finalElapsedSeconds': _elapsedSeconds,
      'finalEvents': List<dynamic>.from((_match['events'] as List?) ?? const []),
      'standingsUpdatedAt': FieldValue.serverTimestamp(),
      'timeoutOwner': null,
      'timeoutRemaining': 0,
    });
    final tournamentId = _match['tournamentId']?.toString();
    if (tournamentId != null && tournamentId.isNotEmpty) {
      await FirebaseFirestore.instance.collection('tournaments').doc(tournamentId).set({'status': 'active', 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    }
    if (!mounted) return;
    setState(() {
      _isPaused = true;
    });
  }

  /// ES: Decide si se avanza de período o se finaliza el partido.
  /// EN: Decides whether to advance the period or finish the match.
  Future<void> _stopAndAdvancePeriod() async {
    if (!_isTimekeeper || _match['status'] == 'finished') return;
    final currentPeriod = (_match['period'] as num?)?.toInt() ?? 1;
    final homeScore = (_match['homeScore'] as num?)?.toInt() ?? 0;
    final awayScore = (_match['awayScore'] as num?)?.toInt() ?? 0;
    final isTied = homeScore == awayScore;
    final canAdvance = currentPeriod < 2 || (currentPeriod == 2 && isTied);
    _timer?.cancel();
    if (!canAdvance) {
      await _finishMatch();
      return;
    }
    final nextPeriod = currentPeriod + 1;
    await _saveMatch({
      'period': nextPeriod,
      'elapsedSeconds': 0,
      'status': 'paused',
      'periodStartedAt': FieldValue.serverTimestamp(),
      'finishedAt': null,
    });
    if (!mounted) return;
    setState(() {
      _elapsedSeconds = 0;
      _isPaused = true;
    });
  }

  /// ES: Construye marcador, cronómetro, planilla y controles según el rol.
  /// EN: Builds the score, timer, score sheet, and role-specific controls.
  @override
  Widget build(BuildContext context) {
    final home = _match['homeTeamName'] ?? _match['localName'] ?? 'Equipo local';
    final away = _match['awayTeamName'] ?? _match['visitorName'] ?? 'Equipo visitante';
    final homeScore = _match['homeScore'] ?? 0;
    final awayScore = _match['awayScore'] ?? 0;
    final events = (_match['events'] as List?)?.cast<Map>() ?? const <Map>[];

    return Scaffold(
      appBar: AppBar(title: const Text('Partido en vivo')),
      bottomNavigationBar: AppBottomNavigationBar(
        selectedIndex: null,
        isAuthenticated: context.watch<AuthBloc>().state is AuthAuthenticated,
      ),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.circle, size: 8, color: _statusColor(_match['status']?.toString())),
          const SizedBox(width: 5),
          Text('${_statusLabel(_match['status']?.toString())} · ${_elapsedLabel()}', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: _statusColor(_match['status']?.toString()))),
        ])),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          Expanded(child: Text(home.toString(), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700))),
          Text('$homeScore  -  $awayScore', style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
          Expanded(child: Text(away.toString(), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700))),
        ]),
        const SizedBox(height: 6),
        Center(
          child: Text(
            ((_match['period'] as num?)?.toInt() ?? 1) <= 2
                ? 'Período ${(_match['period'] as num?)?.toInt() ?? 1} · ${_match['halfDurationMinutes'] ?? 20} min'
                : 'TIEMPO EXTRA',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        if (_canOperate) ...[
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Controles del partido', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
                if (_isTimekeeper) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _match['status'] == 'finished' ? null : ((!_isLiveStatus(_match['status']?.toString()) && _match['status'] != 'paused' && _match['status'] != 'tiempo_muerto') ? _startMatch : (_match['status'] == 'tiempo_muerto' ? (_timeoutOwner == 'arbitros' ? _toggleTimer : null) : _handleTimeout)),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(40),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
                          label: Text(_isPaused ? 'Iniciar / reanudar' : 'Pausar'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _match['status'] == 'finished' ? null : _confirmFinishMatch,
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.red.withValues(alpha: 0.14),
                            foregroundColor: Colors.red.shade300,
                            side: BorderSide(color: Colors.red.shade300, width: 1.4),
                            minimumSize: const Size.fromHeight(40),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: Icon(Icons.stop_circle_outlined, color: Colors.red.shade400),
                          label: const Text('Finalizar partido'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: <int>{1, 2, if (((_match['period'] as num?)?.toInt() ?? 1) > 2) (_match['period'] as num).toInt()}
                        .map((period) => ChoiceChip(
                              label: Text(period <= 2 ? 'Período $period' : 'TIEMPO EXTRA'),
                              selected: (_match['period'] ?? 1) == period,
                              onSelected: (_) => _changePeriod(period),
                            ))
                        .toList(),
                  ),
                ],

              ]),
            ),
          ),
        ],
        const SizedBox(height: 18),
        if (_timeoutOwner != null) ...[
          Card(
            child: ListTile(
              leading: Icon(_timeoutOwner == 'arbitros' ? Icons.pause_circle : Icons.timer, color: Colors.amber),
              title: Text(_timeoutOwner == 'arbitros' ? 'Tiempo muerto de los árbitros' : 'Tiempo muerto · ${_timeoutOwner == 'local' ? _teamName('homeTeamName', 'homeTeam') : _teamName('awayTeamName', 'awayTeam')}'),
              trailing: _timeoutOwner == 'arbitros' ? const Text('En pausa') : Text('$_timeoutRemaining s'),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (_activeSuspensions.isNotEmpty) ...[
          _section('Suspensiones activas', _activeSuspensions.map(_suspensionCard).toList()),
          const SizedBox(height: 12),
        ],
        if (_isReferee || _canUseScoreSheet) _section('Planilla digital', [
          Card(
            margin: EdgeInsets.zero,
            color: _isRosterLocked ? Colors.green.withValues(alpha: 0.12) : null,
            child: ListTile(
              leading: Icon(_isRosterLocked ? Icons.lock : Icons.fact_check_outlined),
              title: Text(_isRosterLocked ? 'Planilla aprobada y bloqueada' : 'Planilla pendiente de aprobación'),
              subtitle: Text(_isRosterLocked ? 'No se permiten cambios en la planilla.' : 'Verifica los jugadores antes de aprobarla.'),
              trailing: !_isRosterLocked && _canUseScoreSheet
                  ? FilledButton.icon(onPressed: _approveRoster, icon: const Icon(Icons.lock), label: const Text('Aprobar'))
                  : null,
            ),
          ),
          const SizedBox(height: 8),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _registrationStream,
            builder: (context, snapshot) {
              final registrations = snapshot.data?.docs.map((doc) => doc.data()).toList() ?? const <Map<String, dynamic>>[];
              final home = _teamRoster(registrations, 'homeTeam', 'homeTeamId');
              final away = _teamRoster(registrations, 'awayTeam', 'awayTeamId');
  final homeName = _teamName('homeTeamName', 'homeTeam');
  final awayName = _teamName('awayTeamName', 'awayTeam');
  final selectedPlayers = _selectedRoster == 'home' ? home : (_selectedRoster == 'away' ? away : const <dynamic>[]);
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(child: _rosterTeamButton('home', homeName)),
          const SizedBox(width: 8),
          Expanded(child: _rosterTeamButton('away', awayName)),
        ],
      ),
      if (_selectedRoster != null) ...[
        const SizedBox(height: 10),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(children: selectedPlayers.isEmpty
                ? [const ListTile(title: Text('No hay jugadores inscritos'))]
                : selectedPlayers.map((player) {
                    final data = player is Map ? player : <String, dynamic>{'name': player};
                    final number = data['number']?.toString() ?? '--';
                    final name = data['name']?.toString() ?? data['fullName']?.toString() ?? 'Jugador';
                    return _playerRow('#$number', name, 0, _selectedRoster == 'home');
                  }).toList()),
          ),
        ),
      ],
    ],
  );
            },
          ),
        ]),
        const SizedBox(height: 18),
        Text('Cronología', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        if (events.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('Aún no hay acciones registradas.'),
          )
        else
  ...events.reversed.map((event) {
  final eventData = Map<String, dynamic>.from(event as Map);
  final eventType = eventData['type']?.toString();
  final eventColor = _chronologyColor(eventType);
  return ListTile(
  dense: true,
  contentPadding: EdgeInsets.zero,
  leading: Container(
  width: 34,
  height: 34,
  decoration: BoxDecoration(
  color: eventColor.withValues(alpha: 0.14),
  borderRadius: BorderRadius.circular(9),
  ),
  child: Icon(_chronologyIcon(eventType), color: eventColor, size: 19),
  ),
  title: Row(
  children: [
  Expanded(child: Text(_eventDescription(eventData), maxLines: 1, overflow: TextOverflow.ellipsis)),
  const SizedBox(width: 6),
  Text(_eventTime(eventData), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
  ],
  ),
  subtitle: Text('Período ${eventData['period'] ?? 1}', maxLines: 1, overflow: TextOverflow.ellipsis),
  );
  }),
        const SizedBox(height: 18),
        Card(
          margin: EdgeInsets.zero,
          child: Column(children: [
            ListTile(
              dense: true,
              title: const Text('Oficiales del partido', style: TextStyle(fontWeight: FontWeight.w700)),
              trailing: IconButton(
                tooltip: _showOfficials ? 'Ocultar oficiales' : 'Mostrar oficiales',
                icon: Icon(_showOfficials ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down),
                onPressed: () => setState(() => _showOfficials = !_showOfficials),
              ),
            ),
            if (_showOfficials) Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(children: [
                _official('Árb. campo 1', _officialDisplayName('refereeOne')),
                _official('Árb. campo 2', _officialDisplayName('refereeTwo')),
                _official('Mesa - Cronometrista', _officialDisplayName('timekeeper')),
                _official('Mesa - Anotador', _officialDisplayName('scorer')),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }

  /// ES: Reconoce los valores almacenados que significan partido en vivo.
  /// EN: Recognizes stored values that indicate a live match.
  bool _isLiveStatus(String? status) {
    final value = status?.trim().toLowerCase();
    return value == 'en_curso' || value == 'en curso' || value == 'en_vivo' || value == 'en vivo' || value == 'playing' || value == 'live' || value == 'jugando';
  }

  /// ES: Convierte el estado del partido en una etiqueta para la interfaz.
  /// EN: Converts match status into a user-facing label.
  String _statusLabel(String? status) {
  if (status == 'tiempo_muerto' || status == 'tiempo muerto' || status == 'timeout') return 'TIEMPO MUERTO';
  if (_isLiveStatus(status)) return 'EN VIVO';
  if (status == 'finished' || status == 'finalizado') return 'FINALIZADO';
  return 'POR INICIAR';
  }

  /// ES: Elige un color de estado para vivo, pausa, finalizado o programado.
  /// EN: Chooses a status color for live, paused, finished, or scheduled matches.
  Color _statusColor(String? status) => status == 'tiempo_muerto' || status == 'tiempo muerto' || status == 'timeout' ? Colors.amber.shade700 : _isLiveStatus(status) ? Colors.green : status == 'finished' ? Colors.blueGrey : Colors.orange;

  /// ES: Formatea el tiempo transcurrido como minutos y segundos.
  /// EN: Formats elapsed time as minutes and seconds.
  String _elapsedLabel() {
    final seconds = _elapsedSeconds > 0 ? _elapsedSeconds : ((_match['elapsedSeconds'] as num?)?.toInt() ?? 0);
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  /// ES: Obtiene el stream de inscripciones aprobadas del torneo actual.
  /// EN: Returns the current tournament's approved registrations stream.
  Stream<QuerySnapshot<Map<String, dynamic>>>? get _registrationStream {
    final tournamentId = _match['tournamentId']?.toString();
    if (tournamentId == null || tournamentId.isEmpty) return null;
    return FirebaseFirestore.instance.collection('tournaments').doc(tournamentId).collection('registrations').where('status', isEqualTo: 'approved').snapshots();
  }

  /// ES: Busca la plantilla que corresponde al equipo local o visitante.
  /// EN: Finds the roster matching the home or away team.
  List<dynamic> _teamRoster(List<Map<String, dynamic>> registrations, String teamKey, String idKey) {
    final id = _match[idKey]?.toString() ?? _match[teamKey]?.toString();
    final registration = registrations.firstWhere((item) => item['id']?.toString() == id || item['teamId']?.toString() == id || item['teamName']?.toString() == _match['${teamKey}Name']?.toString(), orElse: () => <String, dynamic>{});
    return registration['players'] is List ? List<dynamic>.from(registration['players'] as List) : const [];
  }

  /// ES: Devuelve el nombre visible del equipo con alternativa por ID.
  /// EN: Returns the team's display name, falling back to its ID.
  String _teamName(String nameKey, String idKey) => _match[nameKey]?.toString() ?? _match[idKey]?.toString() ?? 'Equipo';

  /// ES: Traduce el color de uniforme del equipo a un color de interfaz.
  /// EN: Maps a team's uniform color to a UI color.
  Color _teamIndicatorColor(String side) {
    final rawColor = _match[side == 'home' ? 'homeTeamColor' : 'awayTeamColor']?.toString().trim().toLowerCase();
    switch (rawColor) {
      case 'rojo':
      case 'red':
        return Colors.red;
      case 'azul':
      case 'blue':
        return Colors.blue;
      case 'amarillo':
      case 'yellow':
        return Colors.amber;
      case 'naranja':
      case 'orange':
        return Colors.orange;
      case 'blanco':
      case 'white':
        return Colors.grey.shade300;
      case 'negro':
      case 'black':
        return Colors.black;
      case 'verde':
      case 'green':
      default:
        return Colors.green;
    }
  }

  /// ES: Asigna un icono al tipo de evento de la cronología.
  /// EN: Selects an icon for a match chronology event type.
  IconData _chronologyIcon(String? type) {
  switch (type) {
  case 'goal':
  return Icons.sports_soccer;
  case 'exclusion':
  return Icons.timer;
  case 'yellowCard':
  return Icons.square;
  case 'redCard':
  return Icons.square;
  case 'timeout':
  return Icons.pause_circle_outline;
  case 'matchStarted':
  return Icons.play_arrow;
  case 'matchFinished':
  return Icons.flag;
  default:
  return Icons.info_outline;
  }
  }

  /// ES: Asigna un color al tipo de evento de la cronología.
  /// EN: Selects a color for a match chronology event type.
  Color _chronologyColor(String? type) {
  switch (type) {
  case 'goal':
  return Colors.green;
  case 'exclusion':
  case 'timeout':
  return Colors.amber.shade700;
  case 'yellowCard':
  return Colors.amber;
  case 'redCard':
  return Colors.red;
  case 'matchStarted':
  return Colors.blue;
  case 'matchFinished':
  return Colors.blueGrey;
  default:
  return Theme.of(context).colorScheme.primary;
  }
  }

  /// ES: Crea una descripción legible para un evento registrado.
  /// EN: Creates a readable description for a recorded event.
  String _eventDescription(Map<String, dynamic> event) {
    final player = event['playerName']?.toString() ?? event['player']?.toString() ?? 'Jugador';
    final type = event['type']?.toString();
    switch (type) {
      case 'goal':
        return '$player anotó un gol';
      case 'exclusion':
        return '$player recibió una exclusión de 2 minutos';
      case 'yellowCard':
        return '$player recibió tarjeta amarilla';
      case 'redCard':
        return '$player recibió tarjeta roja';
      case 'matchStarted':
        return 'Comenzó el partido';
      case 'periodStarted':
        return 'Comenzó el período ${event['period'] ?? ''}'.trim();
      case 'matchFinished':
        return 'Finalizó el partido';
      default:
        return event['description']?.toString() ?? 'Evento del partido';
    }
  }

  /// ES: Formatea el tiempo del período asociado al evento.
  /// EN: Formats the period time associated with an event.
  String _eventTime(Map<String, dynamic> event) {
    final seconds = (event['elapsedSeconds'] as num?)?.toInt();
    if (seconds == null) return "--'";
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  /// ES: Muestra una exclusión activa y el tiempo que falta.
  /// EN: Displays an active suspension and its remaining time.
  Widget _suspensionCard(Map<String, dynamic> suspension) {
    final remaining = (suspension['endsAt'] as DateTime).difference(DateTime.now()).inSeconds.clamp(0, 120);
    final minutes = remaining ~/ 60;
    final seconds = (remaining % 60).toString().padLeft(2, '0');
    final team = suspension['team'] == 'home' ? _teamName('homeTeamName', 'homeTeam') : _teamName('awayTeamName', 'awayTeam');
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.45),
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: Colors.amber.shade700,
          child: Text('$minutes:$seconds', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.black)),
        ),
        title: Row(children: [Expanded(child: Text(suspension['name'].toString(), style: const TextStyle(fontWeight: FontWeight.w700))), Icon(Icons.circle, size: 9, color: _teamIndicatorColor(suspension['team']?.toString() ?? 'home'))]),
        subtitle: Text('Exclusión de 2 minutos · $team'),
        trailing: const Text('Excluido', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
      ),
    );
  }

  /// ES: Abre o cierra la plantilla de un lado del partido.
  /// EN: Expands or collapses a match side's roster.
  Widget _rosterTeamButton(String side, String teamName) => OutlinedButton(
    onPressed: () => setState(() => _selectedRoster = _selectedRoster == side ? null : side),
    style: OutlinedButton.styleFrom(
      backgroundColor: _selectedRoster == side ? Theme.of(context).colorScheme.primaryContainer : null,
      foregroundColor: _selectedRoster == side ? Theme.of(context).colorScheme.onPrimaryContainer : null,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    child: Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: _teamIndicatorColor(side),
            shape: BoxShape.circle,
            border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.45)),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(teamName, overflow: TextOverflow.ellipsis, textAlign: TextAlign.left)),
        Icon(_selectedRoster == side ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down),
      ],
    ),
  );

  /// ES: Agrupa widgets bajo un encabezado de sección.
  /// EN: Groups widgets under a section heading.
  Widget _section(String title, List<Widget> children) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)), const SizedBox(height: 7), ...children]);

  /// ES: Presenta el rol y el nombre de un oficial asignado.
  /// EN: Displays the role and name of an assigned official.
  Widget _official(String role, dynamic name) => ListTile(dense: true, title: Text(role), trailing: Text(name?.toString() ?? 'Sin asignar'));

  final Map<String, Map<String, int>> _playerEvents = {};

  /// ES: Actualiza cada segundo las exclusiones activas y las elimina al vencer.
  /// EN: Updates active suspensions each second and removes expired ones.
  void _startSuspensionCountdown() {
    _suspensionTimer?.cancel();
    _suspensionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _isPaused) return;
      final now = DateTime.now();
      setState(() => _activeSuspensions.removeWhere((item) => (item['endsAt'] as DateTime).isBefore(now)));
    });
  }

  /// ES: Registra un gol, tarjeta o exclusión y sincroniza marcador/eventos.
  /// EN: Records a goal, card, or suspension and syncs scores and events.
  Future<void> _recordPlayerEvent(String playerKey, String event, {bool? isHome, String? playerName}) async {
  if (!_canUseScoreSheet || _isRosterLocked || _match['status']?.toString().toLowerCase() == 'finished' || _match['status']?.toString().toLowerCase() == 'finalizado') return;
    final nextHomeScore = ((_match['homeScore'] as num?)?.toInt() ?? 0) + (event == 'goal' && isHome == true ? 1 : 0);
    final nextAwayScore = ((_match['awayScore'] as num?)?.toInt() ?? 0) + (event == 'goal' && isHome == false ? 1 : 0);
    final suspensionEndsAt = DateTime.now().add(const Duration(minutes: 2));
    final eventData = {'type': event, 'player': playerKey, 'playerName': playerName ?? playerKey, 'team': isHome == true ? 'home' : isHome == false ? 'away' : null, 'period': _match['period'] ?? 1, 'elapsedSeconds': _elapsedSeconds, 'createdAt': DateTime.now().toIso8601String()};
    if (event == 'exclusion') {
      _activeSuspensions.add({'name': playerName ?? playerKey, 'player': playerKey, 'team': isHome == true ? 'home' : 'away', 'endsAt': suspensionEndsAt});
      _startSuspensionCountdown();
    }
    await _saveMatch({'events': FieldValue.arrayUnion([eventData]), if (event == 'goal') 'homeScore': nextHomeScore, if (event == 'goal') 'awayScore': nextAwayScore});
    final currentEvents = (_match['events'] as List?)?.toList() ?? <dynamic>[];
    currentEvents.add(eventData);
    setState(() {
      _match['events'] = currentEvents;
      final events = _playerEvents.putIfAbsent(playerKey, () => <String, int>{});
      events[event] = (events[event] ?? 0) + 1;
    });
  }

  /// ES: Construye una fila de jugador con sus estadísticas y acciones.
  /// EN: Builds a player row with statistics and event actions.
  Widget _playerRow(String number, String name, int goals, bool isHome) {
    final key = '$number-$name';
    final events = _playerEvents[key] ?? const <String, int>{};
    final isExcluded = _activeSuspensions.any((suspension) => suspension['player'] == key);
    final goalColor = isExcluded
        ? Theme.of(context).disabledColor
        : (Theme.of(context).brightness == Brightness.light ? Colors.black : Colors.white);
    return Card(
      child: ListTile(
        leading: Text(number),
        title: Text(name),
        subtitle: Text(
          '${goals + (events['goal'] ?? 0)} goles · Amarillas: ${events['yellowCard'] ?? 0} · Rojas: ${events['redCard'] ?? 0}',
        ),
        trailing: Wrap(spacing: 2, children: [
          _eventButton(
                    Icons.sports_soccer,
                    'goal',
                    key,
                    goalColor,
                    isHome,
                    name,
                    enabled: !isExcluded && _match['status']?.toString().toLowerCase() != 'finished' && _match['status']?.toString().toLowerCase() != 'finalizado',
                  ),
          _textEventButton("2'", 'exclusion', key, Colors.amber, isHome, name, enabled: _match['status']?.toString().toLowerCase() != 'finished' && _match['status']?.toString().toLowerCase() != 'finalizado'),
          _eventButton(Icons.square, 'yellowCard', key, Colors.amber, isHome, name, enabled: _match['status']?.toString().toLowerCase() != 'finished' && _match['status']?.toString().toLowerCase() != 'finalizado'),
          _eventButton(Icons.square, 'redCard', key, Colors.red, isHome, name, enabled: _match['status']?.toString().toLowerCase() != 'finished' && _match['status']?.toString().toLowerCase() != 'finalizado'),
        ]),
      ),
    );
  }

  /// ES: Aplica estilo común a los botones de evento de la planilla.
  /// EN: Applies shared styling to score-sheet event buttons.
  ButtonStyle _eventButtonStyle(Color color) => IconButton.styleFrom(
        backgroundColor: color.withValues(alpha: Theme.of(context).brightness == Brightness.light ? 0.14 : 0.22),
        foregroundColor: color,
        minimumSize: const Size(44, 44),
        maximumSize: const Size(44, 44),
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
      );

  /// ES: Crea un botón con icono para registrar un evento del jugador.
  /// EN: Creates an icon button for recording a player event.
  Widget _eventButton(IconData icon, String event, String playerKey, Color color, bool isHome, String playerName, {bool enabled = true}) => IconButton(
        tooltip: event == 'goal' ? 'Anotar gol' : event == 'yellowCard' ? 'Registrar tarjeta amarilla' : 'Registrar tarjeta roja',
        style: _eventButtonStyle(color),
        onPressed: enabled ? () => _recordPlayerEvent(playerKey, event, isHome: isHome, playerName: playerName) : null,
        icon: Icon(icon, color: color, size: 24),
      );

  /// ES: Crea un botón textual para registrar una exclusión.
  /// EN: Creates a text button for recording a suspension.
  Widget _textEventButton(String label, String event, String playerKey, Color color, bool isHome, String playerName, {bool enabled = true}) => IconButton(
        tooltip: 'Exclusión 2 minutos',
        style: _eventButtonStyle(color),
        onPressed: enabled ? () => _recordPlayerEvent(playerKey, event, isHome: isHome, playerName: playerName) : null,
        icon: Text(label, style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w700)),
      );
}
