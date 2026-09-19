import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../../shared/widgets/app_bottom_navigation_bar.dart';

class LiveMatchScreen extends StatefulWidget {
  const LiveMatchScreen({super.key, required this.matchId, required this.match});
  final String matchId;
  final Map<String, dynamic> match;

  @override
  State<LiveMatchScreen> createState() => _LiveMatchScreenState();
}

class _LiveMatchScreenState extends State<LiveMatchScreen> {
  late final Map<String, dynamic> _match = Map<String, dynamic>.from(widget.match);
  final Map<String, String> _officialNames = {};
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

  @override
  void initState() {
    super.initState();
    _elapsedSeconds = (_match['elapsedSeconds'] as num?)?.toInt() ?? 0;
    _isPaused = !_isLiveStatus(_match['status']?.toString());
    if (_isLiveStatus(_match['status']?.toString())) _startLocalTimer();
    _loadOfficialNames();
    _loadTeamNames();
  }

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
      if (name != null && name.trim().isNotEmpty && mounted) {
        setState(() => _officialNames[id] = name.trim());
      }
    }
  }

  String _officialDisplayName(String key) {
    final value = _match[key]?.toString();
    if (value == null || value.isEmpty) return 'Sin asignar';
    return _match['${key}Name']?.toString() ?? _officialNames[value] ?? 'Sin nombre';
  }

  bool get _isReferee {
    final state = context.read<AuthBloc>().state;
    if (state is! AuthAuthenticated) return false;
    return state.user.roles
        .map((role) => role.trim().toLowerCase())
        .any((role) => role == 'arbitro' || role == 'árbitro' || role == 'referee');
  }

  String? get _currentUid {
    final state = context.read<AuthBloc>().state;
    return state is AuthAuthenticated ? state.user.uid : null;
  }

  bool get _isTimekeeper => _isReferee && _currentUid == _match['timekeeper']?.toString();
  bool get _isScorer => _isReferee && _currentUid == _match['scorer']?.toString();
  bool get _canOperate => _isTimekeeper || _isScorer;
  bool get _canUseScoreSheet => _isTimekeeper || _isScorer;

  @override
  void dispose() {
    _timer?.cancel();
    _suspensionTimer?.cancel();
    _timeoutTimer?.cancel();
    super.dispose();
  }

  void _startLocalTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _isPaused) return;
      setState(() => _elapsedSeconds++);
    });
  }

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

  Future<void> _saveMatch(Map<String, dynamic> data) async {
    await FirebaseFirestore.instance.collection('tournaments').doc(_match['tournamentId']).collection('matches').doc(widget.matchId).update(data);
    if (!mounted) return;
    final localData = <String, dynamic>{
      for (final entry in data.entries)
        if (entry.value is! FieldValue) entry.key: entry.value,
    };
    setState(() => _match.addAll(localData));
  }

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

  Future<void> _changePeriod(int period) async {
    if (!_isTimekeeper) return;
    await _saveMatch({'period': period, 'elapsedSeconds': 0, 'status': 'paused'});
    _timer?.cancel();
    setState(() {
      _elapsedSeconds = 0;
      _isPaused = true;
    });
  }

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

  Future<void> _resetToSecondPeriod() => _startPeriod(2);

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

  Future<void> _finishMatch() async {
    if (!_isTimekeeper || _match['status'] == 'finished') return;
    _timer?.cancel();
    await _saveMatch({
      'status': 'finished',
      'elapsedSeconds': _elapsedSeconds,
      'finishedAt': FieldValue.serverTimestamp(),
    });
    if (!mounted) return;
    setState(() {
      _isPaused = true;
    });
  }

  Future<void> _stopAndAdvancePeriod() async {
    if (!_isTimekeeper || _match['status'] == 'finished') return;
    final currentPeriod = (_match['period'] as num?)?.toInt() ?? 1;
    final homeScore = (_match['homeScore'] as num?)?.toInt() ?? 0;
    final awayScore = (_match['awayScore'] as num?)?.toInt() ?? 0;
    final isTied = homeScore == awayScore;
    final canAdvance = currentPeriod < 2 || isTied;
    final nextPeriod = canAdvance ? currentPeriod + 1 : currentPeriod;
    final nextStatus = canAdvance ? 'paused' : 'finished';
    _timer?.cancel();
    await _saveMatch({
      'period': nextPeriod,
      'elapsedSeconds': 0,
      'status': nextStatus,
      'periodStartedAt': canAdvance ? FieldValue.serverTimestamp() : null,
      'finishedAt': canAdvance ? null : FieldValue.serverTimestamp(),
    });
    if (!mounted) return;
    setState(() {
      _elapsedSeconds = 0;
      _isPaused = true;
    });
  }

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
                          onPressed: ((_match['period'] as num?)?.toInt() ?? 1) == 2 ? _handlePeriodEnd : _resetToSecondPeriod,
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.red.withValues(alpha: 0.14),
                            foregroundColor: Colors.red.shade300,
                            side: BorderSide(color: Colors.red.shade300, width: 1.4),
                            minimumSize: const Size.fromHeight(40),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: Icon(Icons.stop_circle_outlined, color: Colors.red.shade400),
                          label: Text(((_match['period'] as num?)?.toInt() ?? 1) >= 2 ? 'Terminar' : 'Iniciar período 2'),
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
        if (_isReferee) _section('Planilla digital', [
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
            return ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Text(_eventTime(eventData), style: const TextStyle(fontWeight: FontWeight.w700)),
              title: Text(_eventDescription(eventData)),
              subtitle: Text('Período ${eventData['period'] ?? 1}'),
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

  bool _isLiveStatus(String? status) {
    final value = status?.trim().toLowerCase();
    return value == 'en_curso' || value == 'en curso' || value == 'en_vivo' || value == 'en vivo' || value == 'playing' || value == 'live' || value == 'jugando';
  }

  String _statusLabel(String? status) {
    if (_isLiveStatus(status)) return 'EN VIVO';
    if (status == 'finished' || status == 'finalizado') return 'FINALIZADO';
    return 'POR INICIAR';
  }

  Color _statusColor(String? status) => _isLiveStatus(status) ? Colors.green : status == 'finished' ? Colors.blueGrey : Colors.orange;

  String _elapsedLabel() {
    final seconds = _elapsedSeconds > 0 ? _elapsedSeconds : ((_match['elapsedSeconds'] as num?)?.toInt() ?? 0);
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  Stream<QuerySnapshot<Map<String, dynamic>>>? get _registrationStream {
    final tournamentId = _match['tournamentId']?.toString();
    if (tournamentId == null || tournamentId.isEmpty) return null;
    return FirebaseFirestore.instance.collection('tournaments').doc(tournamentId).collection('registrations').where('status', isEqualTo: 'approved').snapshots();
  }

  List<dynamic> _teamRoster(List<Map<String, dynamic>> registrations, String teamKey, String idKey) {
    final id = _match[idKey]?.toString() ?? _match[teamKey]?.toString();
    final registration = registrations.firstWhere((item) => item['id']?.toString() == id || item['teamId']?.toString() == id || item['teamName']?.toString() == _match['${teamKey}Name']?.toString(), orElse: () => <String, dynamic>{});
    return registration['players'] is List ? List<dynamic>.from(registration['players'] as List) : const [];
  }

  String _teamName(String nameKey, String idKey) => _match[nameKey]?.toString() ?? _match[idKey]?.toString() ?? 'Equipo';

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

  String _eventTime(Map<String, dynamic> event) {
    final seconds = (event['elapsedSeconds'] as num?)?.toInt();
    if (seconds == null) return "--'";
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

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

  Widget _section(String title, List<Widget> children) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)), const SizedBox(height: 7), ...children]);
  Widget _official(String role, dynamic name) => ListTile(dense: true, title: Text(role), trailing: Text(name?.toString() ?? 'Sin asignar'));

  final Map<String, Map<String, int>> _playerEvents = {};

  void _startSuspensionCountdown() {
    _suspensionTimer?.cancel();
    _suspensionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final now = DateTime.now();
      setState(() => _activeSuspensions.removeWhere((item) => (item['endsAt'] as DateTime).isBefore(now)));
    });
  }

  Future<void> _recordPlayerEvent(String playerKey, String event, {bool? isHome, String? playerName}) async {
    if (!_canUseScoreSheet) return;
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
                    enabled: !isExcluded,
                  ),
          _textEventButton("2'", 'exclusion', key, Colors.amber, isHome, name),
          _eventButton(Icons.square, 'yellowCard', key, Colors.amber, isHome, name),
          _eventButton(Icons.square, 'redCard', key, Colors.red, isHome, name),
        ]),
      ),
    );
  }

  ButtonStyle _eventButtonStyle(Color color) => IconButton.styleFrom(
        backgroundColor: color.withValues(alpha: Theme.of(context).brightness == Brightness.light ? 0.14 : 0.22),
        foregroundColor: color,
        minimumSize: const Size(44, 44),
        maximumSize: const Size(44, 44),
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
      );

  Widget _eventButton(IconData icon, String event, String playerKey, Color color, bool isHome, String playerName, {bool enabled = true}) => IconButton(
        tooltip: event == 'goal' ? 'Anotar gol' : event == 'yellowCard' ? 'Registrar tarjeta amarilla' : 'Registrar tarjeta roja',
        style: _eventButtonStyle(color),
        onPressed: enabled ? () => _recordPlayerEvent(playerKey, event, isHome: isHome, playerName: playerName) : null,
        icon: Icon(icon, color: color, size: 24),
      );

  Widget _textEventButton(String label, String event, String playerKey, Color color, bool isHome, String playerName) => IconButton(
        tooltip: 'Exclusión 2 minutos',
        style: _eventButtonStyle(color),
        onPressed: () => _recordPlayerEvent(playerKey, event, isHome: isHome, playerName: playerName),
        icon: Text(label, style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w700)),
      );
}
