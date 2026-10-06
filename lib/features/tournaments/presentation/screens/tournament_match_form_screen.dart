import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../referees/domain/referee_directory.dart';
import '../../domain/models/tournament_models.dart';

class TournamentMatchFormScreen extends StatefulWidget {
  const TournamentMatchFormScreen({
    required this.tournament,
    this.match,
    this.matchId,
    super.key,
  });

  final Tournament tournament;
  final Map<String, dynamic>? match;
  final String? matchId;

  @override
  State<TournamentMatchFormScreen> createState() => _TournamentMatchFormScreenState();
}

class _TournamentMatchFormScreenState extends State<TournamentMatchFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _venue = TextEditingController();
  DateTime? _date;
  TimeOfDay? _time;
  String? _home;
  String? _away;
  String? _refereeOne;
  String? _refereeTwo;
  String? _timekeeper;
  String? _scorer;
  int _halfDurationMinutes = 20;
  List<Map<String, dynamic>> _teamOptions = [];
  RefereeDirectory _refereeDirectory = RefereeDirectory.fromDocs(const []);
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final match = widget.match;
    if (match == null) return;

    _home = (match['homeTeam'] ?? match['homeTeamId'] ?? match['local'])?.toString();
    _away = (match['awayTeam'] ?? match['awayTeamId'] ?? match['visitante'])?.toString();
    _refereeOne = match['refereeOne']?.toString();
    _refereeTwo = match['refereeTwo']?.toString();
    _timekeeper = match['timekeeper']?.toString();
    _scorer = match['scorer']?.toString();
    _venue.text = match['venue']?.toString() ?? '';
    _halfDurationMinutes = (match['halfDurationMinutes'] as num?)?.toInt() ?? 20;

    final timestamp = match['date'];
    final date = timestamp is Timestamp ? timestamp.toDate() : DateTime.tryParse(timestamp?.toString() ?? '');
    if (date != null) {
      _date = date;
      _time = TimeOfDay.fromDateTime(date);
    }
  }

  @override
  void dispose() {
    _venue.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _home == _away || _date == null || _time == null) return;

    final conflict = _refereeConflict();
    if (conflict != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF3A321C),
            behavior: SnackBarBehavior.floating,
            content: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.amber),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    conflict,
                    style: const TextStyle(color: Colors.amber, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        );
      }
      return;
    }

    setState(() => _saving = true);
    final matchDate = DateTime(_date!.year, _date!.month, _date!.day, _time!.hour, _time!.minute);

    try {
      final matchData = {
        'homeTeam': _home,
        'homeTeamName': _teamName(_home),
        'homeTeamColor': _teamColor(_home),
        'awayTeam': _away,
        'awayTeamName': _teamName(_away),
        'awayTeamColor': _teamColor(_away),
        'date': Timestamp.fromDate(matchDate),
        'venue': _venue.text.trim(),
        ..._officialFields('refereeOne', _refereeOne),
        ..._officialFields('refereeTwo', _refereeTwo),
        ..._officialFields('timekeeper', _timekeeper),
        ..._officialFields('scorer', _scorer),
        'officialIds': {
          for (final id in [_refereeOne, _refereeTwo, _timekeeper, _scorer])
            ...?_refereeDirectory.find(id)?.aliasIds,
        }.toList(),
        'status': widget.match?['status'] ?? 'scheduled',
        'jornada': widget.match?['jornada'] ?? widget.match?['round'],
        'round': widget.match?['round'] ?? widget.match?['jornada'],
        'leg': widget.match?['leg'],
        'halfDurationMinutes': _halfDurationMinutes,
        if (widget.match == null) 'createdAt': FieldValue.serverTimestamp(),
      };

      final matches = FirebaseFirestore.instance
          .collection('tournaments')
          .doc(widget.tournament.id)
          .collection('matches');

      if (widget.matchId == null) {
        await matches.add(matchData);
      } else {
        await matches.doc(widget.matchId).update(matchData);
      }

      if (mounted) Navigator.of(context).pop();
    } on FirebaseException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No se pudo guardar el partido: ${error.code}. Verifica que las reglas Firestore estén publicadas.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _refereeConflict() {
    final selectedReferees = <String, String>{
      for (final id in _refereeDirectory.find(_refereeOne)?.aliasIds ?? {if (_refereeOne != null) _refereeOne!})
        id: 'Árbitro de campo 1',
      for (final id in _refereeDirectory.find(_refereeTwo)?.aliasIds ?? {if (_refereeTwo != null) _refereeTwo!})
        id: 'Árbitro de campo 2',
    };

    for (final teamId in [_home, _away]) {
      if (teamId == null) continue;
      final team = _teamOptions.firstWhere(
        (item) => item['id'] == teamId,
        orElse: () => <String, dynamic>{},
      );
      final players = team['players'];
      if (players is! List) continue;

      for (final player in players) {
        final playerId = _playerId(player);
        final role = selectedReferees[playerId];
        if (role != null) {
          final teamName = _teamName(teamId);
          return '${_refereeName(playerId)} también está inscrito como jugador en $teamName. No puede ser asignado a un partido de su propio equipo.';
        }
      }
    }
    return null;
  }

  String _playerId(dynamic player) {
    if (player is String) return player;
    if (player is Map) {
      return (player['uid'] ?? player['userId'] ?? player['id'] ?? player['playerId'] ?? '').toString();
    }
    return '';
  }

  String _refereeName(String id) => _refereeDirectory.find(id)?.name ?? id;

  Map<String, dynamic> _officialFields(String key, String? id) {
    final official = _refereeDirectory.find(id);
    return {
      key: official?.id ?? id,
      '${key}Name': official?.name ?? id ?? '',
      '${key}Email': official?.email,
      '${key}Ids': official?.aliasIds.toList() ?? [if (id != null) id],
    };
  }

  String _teamName(String? id) => _teamOptions.firstWhere(
        (team) => team['id'] == id,
        orElse: () => {'name': id ?? 'Equipo'},
      )['name'].toString();

  dynamic _teamColor(String? id) => _teamOptions.firstWhere(
        (team) => team['id'] == id,
        orElse: () => {'color': null},
      )['color'];

  @override
  Widget build(BuildContext context) {
    final teams = FirebaseFirestore.instance
        .collection('tournaments')
        .doc(widget.tournament.id)
        .collection('registrations')
        .where('status', isEqualTo: 'approved')
        .snapshots();
    final referees = FirebaseFirestore.instance
        .collection('users')
        .where('roles', arrayContains: 'arbitro')
        .snapshots();

    return Scaffold(
      appBar: AppBar(title: Text(widget.match == null ? 'Nuevo partido' : 'Editar partido')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: teams,
        builder: (context, teamSnapshot) {
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: referees,
            builder: (context, refereeSnapshot) {
              _teamOptions = (teamSnapshot.data?.docs ?? const []).map((doc) {
                final data = doc.data();
                return <String, dynamic>{
                  'id': doc.id,
                  'name': data['teamName']?.toString() ??
                      data['name']?.toString() ??
                      data['team']?.toString() ??
                      'Equipo ${doc.id}',
                  'color': data['uniformColor'] ?? data['jerseyColor'] ?? data['kitColor'] ?? data['color'],
                };
              }).toList();

              final teamOptions = _teamOptions
                  .map((team) => MapEntry(team['id'].toString(), team['name'].toString()))
                  .toList();
              _refereeDirectory = RefereeDirectory.fromDocs(refereeSnapshot.data?.docs ?? const []);
              _refereeOne = _refereeDirectory.canonicalId(_refereeOne) ?? _refereeOne;
              _refereeTwo = _refereeDirectory.canonicalId(_refereeTwo) ?? _refereeTwo;
              _timekeeper = _refereeDirectory.canonicalId(_timekeeper) ?? _timekeeper;
              _scorer = _refereeDirectory.canonicalId(_scorer) ?? _scorer;
              final refereeOptions = _refereeDirectory.options
                  .map((item) => MapEntry(item.id, item.name))
                  .toList();

              return Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _matchDropdown(
                      'Equipo local',
                      _home,
                      teamOptions,
                      (value) => setState(() => _home = value),
                    ),
                    _matchDropdown(
                      'Equipo visitante',
                      _away,
                      teamOptions,
                      (value) => setState(() => _away = value),
                    ),
                    ListTile(
                      title: Text(
                        _date == null
                            ? 'Fecha'
                            : '${_date!.day.toString().padLeft(2, '0')}/${_date!.month.toString().padLeft(2, '0')}/${_date!.year}',
                      ),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final value = await showDatePicker(
                          context: context,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                          initialDate: DateTime.now(),
                        );
                        if (value != null) setState(() => _date = value);
                      },
                    ),
                    ListTile(
                      title: Text(_time == null ? 'Hora' : _time!.format(context)),
                      trailing: const Icon(Icons.schedule),
                      onTap: () async {
                        final value = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
                        );
                        if (value != null) setState(() => _time = value);
                      },
                    ),
                    TextFormField(
                      controller: _venue,
                      decoration: const InputDecoration(
                        labelText: 'Sede / cancha',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int>(
                      value: _halfDurationMinutes,
                      decoration: const InputDecoration(
                        labelText: 'Duración de cada tiempo',
                        border: OutlineInputBorder(),
                      ),
                      items: const [15, 20, 25, 30, 35]
                          .map((minutes) => DropdownMenuItem(
                                value: minutes,
                                child: Text('$minutes minutos'),
                              ))
                          .toList(),
                      onChanged: (value) => setState(() => _halfDurationMinutes = value ?? 20),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Asignación de jueces',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    _matchDropdown(
                      'Árbitro de campo 1',
                      _refereeOne,
                      refereeOptions,
                      (value) => setState(() => _refereeOne = value),
                    ),
                    _matchDropdown(
                      'Árbitro de campo 2',
                      _refereeTwo,
                      refereeOptions,
                      (value) => setState(() => _refereeTwo = value),
                    ),
                    _matchDropdown(
                      'Mesa - Cronometrista',
                      _timekeeper,
                      refereeOptions,
                      (value) => setState(() => _timekeeper = value),
                    ),
                    _matchDropdown(
                      'Mesa - Anotador',
                      _scorer,
                      refereeOptions,
                      (value) => setState(() => _scorer = value),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      child: Text(_saving ? 'Guardando...' : 'Guardar partido'),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _matchDropdown(
    String label,
    String? value,
    List<MapEntry<String, String>> options,
    ValueChanged<String?> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DropdownButtonFormField<String>(
        value: options.any((item) => item.key == value) ? value : null,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        items: options
            .map((item) => DropdownMenuItem(value: item.key, child: Text(item.value)))
            .toList(),
        onChanged: onChanged,
        validator: (value) => value == null ? 'Selecciona una opción' : null,
      ),
    );
  }
}
