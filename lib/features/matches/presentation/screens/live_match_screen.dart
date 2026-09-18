import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';

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

  @override
  void initState() {
    super.initState();
    _loadOfficialNames();
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

  bool get _canStart {
    final state = context.read<AuthBloc>().state;
    if (state is! AuthAuthenticated) return false;
    final uid = state.user.uid;
    return uid == _match['timekeeper'] || uid == _match['scorer'];
  }

  Future<void> _startMatch() async {
    await FirebaseFirestore.instance.collection('tournaments').doc(_match['tournamentId']).collection('matches').doc(widget.matchId).update({'status': 'playing', 'startedAt': FieldValue.serverTimestamp(), 'period': 1, 'elapsedSeconds': 0});
    setState(() => _match['status'] = 'playing');
  }

  @override
  Widget build(BuildContext context) {
    final home = _match['homeTeamName'] ?? _match['homeTeam'] ?? 'Equipo local';
    final away = _match['awayTeamName'] ?? _match['awayTeam'] ?? 'Equipo visitante';
    final homeScore = _match['homeScore'] ?? 0;
    final awayScore = _match['awayScore'] ?? 0;
    final events = (_match['events'] as List?)?.cast<Map>() ?? const <Map>[];

    return Scaffold(
      appBar: AppBar(title: const Text('Partido en vivo')),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.circle, size: 8, color: _statusColor(_match['status']?.toString())),
          const SizedBox(width: 5),
          Text('${_statusLabel(_match['status']?.toString())} · ${_elapsedLabel()}', style: Theme.of(context).textTheme.labelMedium),
        ])),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          Expanded(child: Text(home.toString(), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700))),
          Text('$homeScore  -  $awayScore', style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
          Expanded(child: Text(away.toString(), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700))),
        ]),
        const SizedBox(height: 6),
        Center(child: Text('Tiempo ${_match['period'] ?? 1} · ${_match['halfDurationMinutes'] ?? 20} min')),
        if (_canStart && _match['status'] != 'playing' && _match['status'] != 'finished') ...[
          const SizedBox(height: 14),
          FilledButton.icon(onPressed: _startMatch, icon: const Icon(Icons.play_arrow), label: const Text('Iniciar partido')),
        ],
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
        const SizedBox(height: 18),
        _section('Planilla digital', [
          _playerRow('#7', 'Jugador local', 0),
          _playerRow('#11', 'Jugador local', 0),
          _playerRow('#9', 'Jugador visitante', 0),
        ]),
        const SizedBox(height: 18),
        Text('Cronología', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        ...events.map((event) => ListTile(dense: true, leading: Text('${event['minute'] ?? "--"}\''), title: Text(event['description']?.toString() ?? 'Evento'))),
      ]),
    );
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'playing': return 'EN VIVO';
      case 'finished': return 'FINALIZADO';
      default: return 'POR INICIAR';
    }
  }

  Color _statusColor(String? status) => status == 'playing' ? Colors.green : status == 'finished' ? Colors.blueGrey : Colors.orange;

  String _elapsedLabel() {
    final seconds = (_match['elapsedSeconds'] as num?)?.toInt() ?? 0;
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  Widget _section(String title, List<Widget> children) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)), const SizedBox(height: 7), ...children]);
  Widget _official(String role, dynamic name) => ListTile(dense: true, title: Text(role), trailing: Text(name?.toString() ?? 'Sin asignar'));
  Widget _playerRow(String number, String name, int goals) => Card(child: ListTile(leading: Text(number), title: Text(name), subtitle: Text('$goals goles'), trailing: Wrap(spacing: 4, children: [IconButton(onPressed: null, icon: const Icon(Icons.sports_handball)), IconButton(onPressed: null, icon: const Icon(Icons.crop_square)), IconButton(onPressed: null, icon: const Icon(Icons.square, color: Colors.amber)), IconButton(onPressed: null, icon: const Icon(Icons.square, color: Colors.red))])));
}
