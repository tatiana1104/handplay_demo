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
  int _elapsedSeconds = 0;
  bool _isPaused = true;

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
    super.dispose();
  }

  void _startLocalTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _isPaused) return;
      setState(() => _elapsedSeconds++);
    });
  }

  void _toggleTimer() {
    if (!_isTimekeeper) return;
    setState(() => _isPaused = !_isPaused);
    if (_isPaused) {
      _timer?.cancel();
    } else {
      _startLocalTimer();
    }
    _saveMatch({'status': _isPaused ? 'paused' : 'playing', 'elapsedSeconds': _elapsedSeconds});
  }

  Future<void> _saveMatch(Map<String, dynamic> data) async {
    await FirebaseFirestore.instance.collection('tournaments').doc(_match['tournamentId']).collection('matches').doc(widget.matchId).update(data);
    if (mounted) setState(() => _match.addAll(data));
  }

  Future<void> _startMatch() async {
    _elapsedSeconds = (_match['elapsedSeconds'] as num?)?.toInt() ?? 0;
    setState(() => _isPaused = false);
    await _saveMatch({'status': 'en_curso', 'startedAt': FieldValue.serverTimestamp(), 'period': _match['period'] ?? 1, 'elapsedSeconds': _elapsedSeconds});
    _startLocalTimer();
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
        Center(child: Text((_match['period'] as num? ?? 1) <= 2 ? 'Período ${_match['period'] ?? 1} · ${_match['halfDurationMinutes'] ?? 20} min' : 'Desempate ${_match['period'] ?? 1} · ${_match['halfDurationMinutes'] ?? 20} min')),
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
                          onPressed: _match['status'] == 'finished' ? null : ((!_isLiveStatus(_match['status']?.toString()) && _match['status'] != 'paused' && _match['status'] != 'finished') ? _startMatch : _toggleTimer),
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
                          onPressed: _match['status'] == 'finished' ? null : _finishMatch,
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.red.withValues(alpha: 0.14),
                            foregroundColor: Colors.red.shade300,
                            side: BorderSide(color: Colors.red.shade300, width: 1.4),
                            minimumSize: const Size.fromHeight(40),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: Icon(Icons.stop_circle_outlined, color: Colors.red.shade400),
                          label: const Text('Restablecer'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: <int>{1, 2, if (((_match['period'] as num?)?.toInt() ?? 1) > 2) (_match['period'] as num).toInt()}
                        .map((period) => ChoiceChip(
                              label: Text(period <= 2 ? 'Período $period' : 'Desempate $period'),
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
        if (_isReferee) _section('Planilla digital', [
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _registrationStream,
            builder: (context, snapshot) {
              final registrations = snapshot.data?.docs.map((doc) => doc.data()).toList() ?? const <Map<String, dynamic>>[];
              final home = _teamRoster(registrations, 'homeTeam', 'homeTeamId');
              final away = _teamRoster(registrations, 'awayTeam', 'awayTeamId');
              return Column(children: [
                _teamRosterButton(_teamName('homeTeamName', 'homeTeam'), home),
                const SizedBox(height: 8),
                _teamRosterButton(_teamName('awayTeamName', 'awayTeam'), away),
              ]);
            },
          ),
        ]),
        const SizedBox(height: 18),
        Text('Cronología', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        ...events.map((event) => ListTile(dense: true, leading: Text('${event['minute'] ?? "--"}\''), title: Text(event['description']?.toString() ?? 'Evento'))),
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

  Widget _teamRosterButton(String teamName, List<dynamic> players) => ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14),
        title: Text(teamName, style: const TextStyle(fontWeight: FontWeight.w700)),
        children: players.isEmpty
            ? [const ListTile(title: Text('No hay jugadores inscritos'))]
            : players.map((player) {
                final data = player is Map ? player : <String, dynamic>{'name': player};
                final number = data['number']?.toString() ?? '--';
                final name = data['name']?.toString() ?? data['fullName']?.toString() ?? 'Jugador';
                return _playerRow('#$number', name, 0);
              }).toList(),
      );

  Widget _section(String title, List<Widget> children) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)), const SizedBox(height: 7), ...children]);
  Widget _official(String role, dynamic name) => ListTile(dense: true, title: Text(role), trailing: Text(name?.toString() ?? 'Sin asignar'));

  final Map<String, Map<String, int>> _playerEvents = {};

  Future<void> _recordPlayerEvent(String playerKey, String event) async {
    if (!_canUseScoreSheet) return;
    final eventData = {'type': event, 'player': playerKey, 'period': _match['period'] ?? 1, 'elapsedSeconds': _elapsedSeconds, 'createdAt': DateTime.now().toIso8601String()};
    await _saveMatch({'events': FieldValue.arrayUnion([eventData])});
    setState(() {
      final events = _playerEvents.putIfAbsent(playerKey, () => <String, int>{});
      events[event] = (events[event] ?? 0) + 1;
    });
  }

  Widget _playerRow(String number, String name, int goals) {
    final key = '$number-$name';
    final events = _playerEvents[key] ?? const <String, int>{};
    return Card(
      child: ListTile(
        leading: Text(number),
        title: Text(name),
        subtitle: Text('${goals + (events['goal'] ?? 0)} goles'),
        trailing: Wrap(spacing: 2, children: [
          _eventButton(
                    Icons.sports_handball,
                    'goal',
                    key,
                    Theme.of(context).brightness == Brightness.light ? Colors.black : Colors.white,
                  ),
          _textEventButton("2'", 'exclusion', key, Colors.amber),
          _eventButton(Icons.square, 'yellowCard', key, Colors.amber),
          _eventButton(Icons.square, 'redCard', key, Colors.red),
        ]),
      ),
    );
  }

  Widget _eventButton(IconData icon, String event, String playerKey, Color color) => IconButton(
        tooltip: event == 'goal' ? 'Anotar gol' : event == 'yellowCard' ? 'Tarjeta amarilla' : 'Tarjeta roja',
        visualDensity: VisualDensity.compact,
        onPressed: () => _recordPlayerEvent(playerKey, event),
        icon: Icon(icon, color: color, size: 20),
      );

  Widget _textEventButton(String label, String event, String playerKey, Color color) => IconButton(
        tooltip: 'Exclusión 2 minutos',
        visualDensity: VisualDensity.compact,
        onPressed: () => _recordPlayerEvent(playerKey, event),
        icon: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
      );
}
