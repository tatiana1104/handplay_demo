import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../matches/presentation/widgets/match_status_label.dart';
import '../../../referees/domain/referee_directory.dart';
import 'package:go_router/go_router.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';

import '../../../../core/routing/route_names.dart';

import '../../domain/models/tournament_models.dart';
import '../../../teams/data/team_repository.dart';
import '../../../teams/domain/team_stats_calculator.dart' show formatCategory;
import '../../../teams/presentation/screens/team_detail_screen.dart';
import '../../../matches/data/match_repository.dart';
import '../../../../shared/widgets/app_bottom_navigation_bar.dart';
import 'team_registration_screen.dart';
import '../utils/standings_calculator.dart';

/// Resumen responsive del torneo seleccionado.
/// El ListView permite que la información crezca sin desbordarse.
/// EN: Responsive overview of the selected tournament and its live information.
/// ES: Resume el torneo seleccionado con información adaptable y en vivo.

/// ES: Normaliza nombres de roles para comparar variantes con y sin tilde.
/// EN: Normalizes role names so accented and unaccented variants match.
String _normalizeRole(String role) => role
    .trim()
    .toLowerCase()
    .replaceAll('á', 'a')
    .replaceAll('é', 'e')
    .replaceAll('í', 'i')
    .replaceAll('ó', 'o')
    .replaceAll('ú', 'u');

class TournamentDetailScreen extends StatelessWidget {
  /// ES: Crea la vista de detalle del torneo.
  /// EN: Creates the tournament detail view.
  const TournamentDetailScreen({required this.tournament, super.key});

  final Tournament tournament;

  /// ES: Calcula permisos y compone los datos y acciones del torneo.
  /// EN: Resolves permissions and builds tournament data and actions.
  @override
  Widget build(BuildContext context) {
    final status = tournament.status.toLowerCase();
    final registrationClosed = tournament.registrationDeadline != null && DateTime.now().isAfter(tournament.registrationDeadline!);
    final colors = Theme.of(context).colorScheme;
    final authState = context.watch<AuthBloc>().state;
    final roles = authState is AuthAuthenticated
        ? authState.user.roles.map(_normalizeRole).toSet()
        : const <String>{};
    // Jugador o entrenador tienen prioridad y pueden inscribir equipo,
    // aunque también tengan el rol de árbitro.
    final hasPlayerOrCoachRole = roles.any(
      (role) => role == 'jugador' || role == 'player' || role == 'entrenador' || role == 'coach',
    );
    final hasBlockedRole = roles.any(
      (role) => role == 'admin' || role == 'admin_liga' || role == 'administrador' || role == 'arbitro',
    );
    final canRegisterTeam = hasPlayerOrCoachRole || !hasBlockedRole;

    return Scaffold(
      appBar: AppBar(title: Text(tournament.name.isEmpty ? 'Detalle del torneo' : tournament.name)),
      bottomNavigationBar: AppBottomNavigationBar(selectedIndex: 0),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 24 + MediaQuery.paddingOf(context).bottom),
        children: [
          Text('LIGA DE BALONMANO DEL CAQUETÁ', style: Theme.of(context).textTheme.labelSmall?.copyWith(letterSpacing: 1.2, fontWeight: FontWeight.w700, color: colors.primary)),
          const SizedBox(height: 6),
          Text(tournament.name, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('Seguimiento en tiempo real del torneo', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant)),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _TournamentLiveStatus(tournament: tournament, fallbackStatus: tournament.effectiveStatus),
            _InfoBadge(label: _formatLabel(tournament.format), color: colors.primary),
          ]),
          const SizedBox(height: 16),
          _StatsGrid(tournament: tournament),
          const SizedBox(height: 18),
          _SectionTitle(
            title: 'Tabla de posiciones',
            action: 'Ver completa',
            onAction: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => _FullStandingsScreen(tournament: tournament)),
            ),
          ),
          const SizedBox(height: 8),
          _StandingsSummary(tournament: tournament),
          const SizedBox(height: 18),
          const _SectionTitle(title: 'Destacados'),
          const SizedBox(height: 8),
          _Highlights(tournament: tournament),
          const SizedBox(height: 18),
          const _SectionTitle(title: 'Información del torneo'),
          const SizedBox(height: 8),
          _DetailsCard(tournament: tournament),
          const SizedBox(height: 18),
          if (tournament.publicRegistration && canRegisterTeam)
            FilledButton.icon(
              onPressed: registrationClosed
                  ? null
                  : () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => TeamRegistrationScreen(tournament: tournament)),
                      ),
              icon: Icon(registrationClosed ? Icons.lock_clock_outlined : Icons.group_add_rounded),
              label: Text(registrationClosed ? 'Inscripciones cerradas' : 'Inscribir mi equipo'),
            ),
          if (registrationClosed)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'La fecha límite de inscripción ya pasó. Las solicitudes enviadas todavía pueden modificarse.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}

/// ES: Muestra conteos de equipos y jornadas obtenidos en vivo.
/// EN: Shows live counts of approved teams and match rounds.
class _StatsGrid extends StatelessWidget {
  /// ES: Crea la cuadrícula de métricas del torneo.
  /// EN: Creates the tournament metrics grid.
  const _StatsGrid({required this.tournament});
  final Tournament tournament;

  /// ES: Suscribe los conteos y permite abrir sus listas detalladas.
  /// EN: Subscribes to counts and opens their detailed lists.
  @override
  Widget build(BuildContext context) {
    final approvedTeams = FirebaseFirestore.instance
        .collection('tournaments')
        .doc(tournament.id)
        .collection('registrations')
        .where('status', isEqualTo: 'approved')
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: approvedTeams,
      builder: (context, snapshot) {
        final count = snapshot.data?.docs.length ?? 0;
        final hasError = snapshot.hasError;
        return GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.45,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _StatCard(
              label: 'Equipos',
              value: hasError ? '—' : '$count',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => _ApprovedTeamsScreen(tournament: tournament),
                ),
              ),
            ),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('tournaments')
                  .doc(tournament.id)
                  .collection('matches')
                  .snapshots(),
              builder: (context, matchesSnapshot) {
                final matches = matchesSnapshot.data?.docs ?? const [];
                final rounds = matches.map((doc) => (doc.data()['jornada'] ?? doc.data()['round'] ?? 1) as num).toSet().length;
                final currentRound = matches.isEmpty ? 0 : matches.map((doc) => (doc.data()['jornada'] ?? doc.data()['round'] ?? 1) as num).reduce((a, b) => a > b ? a : b);
                return _StatCard(
                  label: 'Jornada',
                  value: rounds == 0 ? '0 / 0' : '$currentRound / $rounds',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => _MatchesScreen(tournament: tournament)),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

/// ES: Contenedor de jornadas y partidos del torneo.
/// EN: Container for the tournament's rounds and matches.
class _MatchesScreen extends StatelessWidget {
  /// ES: Crea la pantalla de partidos y jornadas.
  /// EN: Creates the rounds and matches screen.
  const _MatchesScreen({required this.tournament});
  final Tournament tournament;

  /// ES: Construye la lista de partidos y la acción de alta para el admin.
  /// EN: Builds the match list and the administrator's add action.
  @override
  Widget build(BuildContext context) {
    final isAdmin = FirebaseAuth.instance.currentUser?.uid == tournament.adminId;
    return Scaffold(
        appBar: AppBar(
          title: const Text('Jornadas y partidos'),
          actions: [
            if (isAdmin)
              IconButton(
                tooltip: 'Nuevo partido',
                icon: const Icon(Icons.add),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => _NewMatchScreen(tournament: tournament)),
                ),
              ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _MatchesSection(tournament: tournament),
          ],
        ),
      );
  }
}

/// ES: Formulario para crear o editar un partido y asignar sus oficiales.
/// EN: Form for creating or editing a match and assigning its officials.
class _NewMatchScreen extends StatefulWidget {
  /// ES: Crea el formulario en modo nuevo o edición.
  /// EN: Creates the form in create or edit mode.
  const _NewMatchScreen({required this.tournament, this.match, this.matchId});
  final Tournament tournament;
  final Map<String, dynamic>? match;
  final String? matchId;

  /// ES: Crea el estado que administra campos y validaciones.
  /// EN: Creates the state that manages match fields and validation.
  @override
  State<_NewMatchScreen> createState() => _NewMatchScreenState();
}

class _NewMatchScreenState extends State<_NewMatchScreen> {
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

  /// ES: Restaura los datos al editar un partido existente.
  /// EN: Restores values when editing an existing match.
  @override
  void initState() {
    super.initState();
    final match = widget.match;
    if (match == null) return;
    _home = match['homeTeam']?.toString();
    _away = match['awayTeam']?.toString();
    _refereeOne = match['refereeOne']?.toString();
    _refereeTwo = match['refereeTwo']?.toString();
    _timekeeper = match['timekeeper']?.toString();
    _scorer = match['scorer']?.toString();
    _venue.text = match['venue']?.toString() ?? '';
    _halfDurationMinutes = (match['halfDurationMinutes'] as num?)?.toInt() ?? 20;
    final timestamp = match['date'];
    final date = timestamp is Timestamp ? timestamp.toDate() : DateTime.tryParse(timestamp?.toString() ?? '');
    if (date != null) { _date = date; _time = TimeOfDay.fromDateTime(date); }
  }

  /// ES: Libera el controlador del campo de sede.
  /// EN: Releases the venue field controller.
  @override
  void dispose() { _venue.dispose(); super.dispose(); }

  /// ES: Valida conflictos de oficiales y guarda el partido.
  /// EN: Validates official conflicts and saves the match.
  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _home == _away || _date == null || _time == null) return;

    final conflict = _refereeConflict();
    if (conflict != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF3A321C),
            behavior: SnackBarBehavior.floating,
            content: Row(children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.amber),
              const SizedBox(width: 10),
              Expanded(child: Text(conflict, style: const TextStyle(color: Colors.amber, fontSize: 12))),
            ]),
          ),
        );
      }
      return;
    }

    setState(() => _saving = true);
    final matchDate = DateTime(_date!.year, _date!.month, _date!.day, _time!.hour, _time!.minute);
    try {
      final matchData = {
        'homeTeam': _home, 'homeTeamName': _teamName(_home), 'homeTeamColor': _teamColor(_home),
        'awayTeam': _away, 'awayTeamName': _teamName(_away), 'awayTeamColor': _teamColor(_away),
        'date': Timestamp.fromDate(matchDate), 'venue': _venue.text.trim(),
        ..._officialFields('refereeOne', _refereeOne),
        ..._officialFields('refereeTwo', _refereeTwo),
        ..._officialFields('timekeeper', _timekeeper),
        ..._officialFields('scorer', _scorer),
        'officialIds': {
          for (final id in [_refereeOne, _refereeTwo, _timekeeper, _scorer]) ...?_refereeDirectory.find(id)?.aliasIds,
        }.toList(),
        'status': widget.match?['status'] ?? 'scheduled', 'halfDurationMinutes': _halfDurationMinutes,
        if (widget.match == null) 'createdAt': FieldValue.serverTimestamp(),
      };
      final matches = FirebaseFirestore.instance.collection('tournaments').doc(widget.tournament.id).collection('matches');
      if (widget.matchId == null) {
        await matches.add(matchData);
      } else {
        await matches.doc(widget.matchId).update(matchData);
      }
      if (mounted) Navigator.of(context).pop();
    } on FirebaseException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo guardar el partido: ${error.code}. Verifica que las reglas Firestore estén publicadas.')));
    } finally { if (mounted) setState(() => _saving = false); }
  }

  /// ES: Detecta si un árbitro de campo también juega en uno de los equipos.
  /// EN: Checks whether a field referee also plays for either team.
  String? _refereeConflict() {
    final selectedReferees = <String, String>{
      for (final id in _refereeDirectory.find(_refereeOne)?.aliasIds ?? {if (_refereeOne != null) _refereeOne!}) id: 'Árbitro de campo 1',
      for (final id in _refereeDirectory.find(_refereeTwo)?.aliasIds ?? {if (_refereeTwo != null) _refereeTwo!}) id: 'Árbitro de campo 2',
    };
    for (final teamId in [_home, _away]) {
      if (teamId == null) continue;
      final team = _teamOptions.firstWhere((item) => item['id'] == teamId, orElse: () => <String, dynamic>{});
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

  /// ES: Extrae un ID de jugador desde los formatos de datos admitidos.
  /// EN: Extracts a player ID from supported data formats.
  String _playerId(dynamic player) {
    if (player is String) return player;
    if (player is Map) {
      return (player['uid'] ?? player['userId'] ?? player['id'] ?? player['playerId'] ?? '').toString();
    }
    return '';
  }

  /// ES: Busca el nombre del árbitro o devuelve su ID como alternativa.
  /// EN: Looks up the referee name or falls back to the ID.
  String _refereeName(String id) => _refereeDirectory.find(id)?.name ?? id;

  /// ES: Crea los campos Firestore del oficial seleccionado.
  /// EN: Builds the Firestore fields for the selected official.
  Map<String, dynamic> _officialFields(String key, String? id) {
    final official = _refereeDirectory.find(id);
    return {
      key: official?.id ?? id,
      '${key}Name': official?.name ?? id ?? '',
      '${key}Email': official?.email,
      '${key}Ids': official?.aliasIds.toList() ?? [if (id != null) id],
    };
  }

  /// ES: Obtiene el nombre visible del equipo desde las opciones cargadas.
  /// EN: Resolves the team's display name from the loaded options.
  String _teamName(String? id) => _teamOptions.firstWhere((team) => team['id'] == id, orElse: () => {'name': id ?? 'Equipo'} )['name'].toString();

  /// ES: Obtiene el color de uniforme del equipo seleccionado.
  /// EN: Gets the uniform color for the selected team.
  dynamic _teamColor(String? id) => _teamOptions.firstWhere((team) => team['id'] == id, orElse: () => {'color': null})['color'];

  /// ES: Carga equipos y oficiales y construye el formulario del partido.
  /// EN: Loads teams and officials, then builds the match form.
  @override
  Widget build(BuildContext context) {
    final teams = FirebaseFirestore.instance.collection('tournaments').doc(widget.tournament.id).collection('registrations').where('status', isEqualTo: 'approved').snapshots();
    final referees = FirebaseFirestore.instance.collection('users').where('roles', arrayContains: 'arbitro').snapshots();
    return Scaffold(
      appBar: AppBar(title: Text(widget.match == null ? 'Nuevo partido' : 'Editar partido')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(stream: teams, builder: (context, teamSnapshot) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(stream: referees, builder: (context, refereeSnapshot) {
          _teamOptions = (teamSnapshot.data?.docs ?? const []).map((doc) {
            final data = doc.data();
            return <String, dynamic>{
              'id': doc.id,
              'name': data['teamName']?.toString() ?? data['name']?.toString() ?? data['team']?.toString() ?? 'Equipo ${doc.id}',
              'color': data['uniformColor'] ?? data['jerseyColor'] ?? data['kitColor'] ?? data['color'],
            };
          }).toList();
          final teamOptions = _teamOptions.map((team) => MapEntry(team['id'].toString(), team['name'].toString())).toList();
          _refereeDirectory = RefereeDirectory.fromDocs(refereeSnapshot.data?.docs ?? const []);
          _refereeOne = _refereeDirectory.canonicalId(_refereeOne) ?? _refereeOne;
          _refereeTwo = _refereeDirectory.canonicalId(_refereeTwo) ?? _refereeTwo;
          _timekeeper = _refereeDirectory.canonicalId(_timekeeper) ?? _timekeeper;
          _scorer = _refereeDirectory.canonicalId(_scorer) ?? _scorer;
          final refereeOptions = _refereeDirectory.options.map((item) => MapEntry(item.id, item.name)).toList();
          return Form(key: _formKey, child: ListView(padding: const EdgeInsets.all(16), children: [
            _matchDropdown('Equipo local', _home, teamOptions, (value) => setState(() => _home = value)),
            _matchDropdown('Equipo visitante', _away, teamOptions, (value) => setState(() => _away = value)),
            ListTile(title: Text(_date == null ? 'Fecha' : '${_date!.day.toString().padLeft(2, '0')}/${_date!.month.toString().padLeft(2, '0')}/${_date!.year}'), trailing: const Icon(Icons.calendar_today), onTap: () async { final value = await showDatePicker(context: context, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)), initialDate: DateTime.now()); if (value != null) setState(() => _date = value); }),
            ListTile(title: Text(_time == null ? 'Hora' : _time!.format(context)), trailing: const Icon(Icons.schedule), onTap: () async { final value = await showTimePicker(context: context, initialTime: TimeOfDay.now()); if (value != null) setState(() => _time = value); }),
            TextFormField(controller: _venue, decoration: const InputDecoration(labelText: 'Sede / cancha', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            DropdownButtonFormField<int>(value: _halfDurationMinutes, decoration: const InputDecoration(labelText: 'Duración de cada tiempo', border: OutlineInputBorder()), items: const [15, 20, 25, 30, 35].map((minutes) => DropdownMenuItem(value: minutes, child: Text('$minutes minutos'))).toList(), onChanged: (value) => setState(() => _halfDurationMinutes = value ?? 20)),
            const SizedBox(height: 16),
            Text('Asignación de jueces', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            _matchDropdown('Árbitro de campo 1', _refereeOne, refereeOptions, (value) => setState(() => _refereeOne = value)),
            _matchDropdown('Árbitro de campo 2', _refereeTwo, refereeOptions, (value) => setState(() => _refereeTwo = value)),
            _matchDropdown('Mesa - Cronometrista', _timekeeper, refereeOptions, (value) => setState(() => _timekeeper = value)),
            _matchDropdown('Mesa - Anotador', _scorer, refereeOptions, (value) => setState(() => _scorer = value)),
            const SizedBox(height: 16),
            FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Guardando...' : 'Guardar partido')),
          ]));
        });
      }),
    );
  }

  /// ES: Construye un selector obligatorio de equipo u oficial.
  /// EN: Builds a required dropdown for a team or match official.
  Widget _matchDropdown(String label, String? value, List<MapEntry<String, String>> options, ValueChanged<String?> onChanged) => Padding(padding: const EdgeInsets.only(bottom: 10), child: DropdownButtonFormField<String>(value: options.any((item) => item.key == value) ? value : null, decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()), items: options.map((item) => DropdownMenuItem(value: item.key, child: Text(item.value))).toList(), onChanged: onChanged, validator: (value) => value == null ? 'Selecciona una opción' : null));
}

/// ES: Agrupa partidos por fecha y muestra detalles de cada encuentro.
/// EN: Groups matches by date and displays each match's details.
class _MatchesSection extends StatelessWidget {
  /// ES: Crea la sección de partidos para el torneo indicado.
  /// EN: Creates the match section for the supplied tournament.
  const _MatchesSection({required this.tournament});
  final Tournament tournament;

  /// ES: Resuelve nombres y uniformes y presenta los partidos agrupados.
  /// EN: Resolves team names and uniforms and displays grouped matches.
  @override
  Widget build(BuildContext context) {
    final isAdmin = FirebaseAuth.instance.currentUser?.uid == tournament.adminId;
    final stream = MatchRepository().watchTournamentMatchDocuments(tournament.id);
    final teamsStream = FirebaseFirestore.instance.collection('tournaments').doc(tournament.id).collection('registrations').snapshots();
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: teamsStream,
        builder: (context, teamsSnapshot) {
        final matches = snapshot.data?.docs ?? const [];
        final teamsById = <String, Map<String, dynamic>>{
          for (final doc in teamsSnapshot.data?.docs ?? const []) doc.id: doc.data(),
        };
        if (matches.isEmpty) {
          return const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _SectionTitle(title: 'Partidos'),
            SizedBox(height: 8),
            Card(child: ListTile(title: Text('Aún no hay partidos programados.'))),
          ]);
        }
        final grouped = <String, List<Map<String, dynamic>>>{};
        for (final doc in matches) {
          final data = Map<String, dynamic>.from(doc.data());
          data['id'] = doc.id;
          final date = _matchDateKey(data['date'] ?? data['fecha']);
          final homeId = data['homeTeam']?.toString() ?? data['local']?.toString();
          final awayId = data['awayTeam']?.toString() ?? data['visitante']?.toString();
          final homeRegistration = teamsById[homeId];
          final awayRegistration = teamsById[awayId];
          data['homeTeamName'] = _registrationTeamName(homeRegistration, data['homeTeamName'] ?? homeId ?? 'Equipo local');
          data['awayTeamName'] = _registrationTeamName(awayRegistration, data['awayTeamName'] ?? awayId ?? 'Equipo visitante');
          data['homeTeamColor'] = homeRegistration?['uniformColor'] ?? data['homeTeamColor'];
          data['awayTeamColor'] = awayRegistration?['uniformColor'] ?? data['awayTeamColor'];
          grouped.putIfAbsent(date, () => []).add(data);
        }
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const _SectionTitle(title: 'Partidos'),
          const SizedBox(height: 8),
          ...grouped.entries.map((entry) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(padding: const EdgeInsets.only(left: 4, bottom: 6, top: 4), child: Text(_matchDateLabel(entry.key), style: Theme.of(context).textTheme.labelMedium)),
                ...entry.value.map((match) {
                  final home = match['homeTeamName']?.toString() ?? match['localName']?.toString() ?? match['homeTeam']?.toString() ?? match['local']?.toString() ?? 'Equipo local';
                  final away = match['awayTeamName']?.toString() ?? match['visitorName']?.toString() ?? match['awayTeam']?.toString() ?? match['visitante']?.toString() ?? 'Equipo visitante';
                  final homeColor = _teamColorFromValue(match['homeTeamColor'], Colors.green);
                  final awayColor = _teamColorFromValue(match['awayTeamColor'], Colors.deepOrange);
                  final time = match['time']?.toString() ?? _matchTimeLabel(match['date']);
                  final venue = match['venue']?.toString() ?? match['sede']?.toString() ?? match['cancha']?.toString() ?? 'Sede por definir';
                  final status = match['status']?.toString() ?? 'scheduled';
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: InkWell(
                      onTap: () => context.go(RouteNames.liveMatch, extra: {...match, 'id': match['id']?.toString() ?? '', 'tournamentId': tournament.id}),
                      child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Align(
                          alignment: Alignment.topRight,
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 120),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                                color: matchStatusColor(context, status).withValues(alpha: .16),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: matchStatusColor(context, status).withValues(alpha: .28)),
                              ),
                            child: Text(
                              matchStatusLabel(status),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: matchStatusColor(context, status), fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(children: [
                          Expanded(child: _TeamMatchLabel(label: 'LOCAL', name: home, color: homeColor)),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (status.toLowerCase() == 'finished' || status.toLowerCase() == 'finalizado')
                                Text('${match['homeScore'] ?? match['finalHomeScore'] ?? 0} - ${match['awayScore'] ?? match['finalAwayScore'] ?? 0}', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                              if (status.toLowerCase() != 'finished' && status.toLowerCase() != 'finalizado')
                                Text(time, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                              const SizedBox(height: 3),
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 105),
                                child: Text(
                                  venue,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                                ),
                              ),
                            ],
                          ),
                          Expanded(child: Align(alignment: Alignment.centerRight, child: _TeamMatchLabel(label: 'VISITANTE', name: away, color: awayColor, alignEnd: true))),
                        ]),
                        if (isAdmin) ...[
                          const Divider(height: 20),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              TextButton.icon(
                                onPressed: () async {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => _NewMatchScreen(
                                        tournament: tournament,
                                        match: match,
                                        matchId: match['id']?.toString(),
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.edit_outlined, size: 17),
                                label: const Text('Editar'),
                              ),
                              TextButton.icon(
                                onPressed: () async {
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (dialogContext) => AlertDialog(
                                      title: const Text('Eliminar partido'),
                                      content: const Text('Esta acción no se puede deshacer.'),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
                                        FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Eliminar')),
                                      ],
                                    ),
                                  );
                                  if (confirmed == true && context.mounted) {
                                    await FirebaseFirestore.instance
                                        .collection('tournaments')
                                        .doc(tournament.id)
                                        .collection('matches')
                                        .doc(match['id']?.toString())
                                        .delete();
                                  }
                                },
                                icon: const Icon(Icons.delete_outline, size: 17),
                                label: const Text('Eliminar'),
                              ),
                            ],
                          ),
                        ],
                      ]),
                      ),
                    ),
                  );
                }),
              ])),
        ]);
        },
      ),
    );
  }
}

/// ES: Etiqueta local/visitante con nombre y color del equipo.
/// EN: Home/away label showing a team's name and color.
class _TeamMatchLabel extends StatelessWidget {
  /// ES: Crea la etiqueta de equipo para una tarjeta de partido.
  /// EN: Creates a team label for a match card.
  const _TeamMatchLabel({required this.label, required this.name, required this.color, this.alignEnd = false});
  final String label;
  final String name;
  final Color color;
  final bool alignEnd;

  /// ES: Alinea y dibuja la etiqueta del equipo.
  /// EN: Aligns and renders the team label.
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          Row(mainAxisSize: MainAxisSize.min, children: [
            if (!alignEnd) Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            if (!alignEnd) const SizedBox(width: 4),
            Flexible(child: Text(name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
            if (alignEnd) const SizedBox(width: 4),
            if (alignEnd) Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          ]),
        ],
      );
}

/// ES: Elige el color semántico que corresponde al estado del torneo.
/// EN: Selects the semantic color for the tournament's status.
Color _tournamentStatusColor(String? status) {
  final value = status?.trim().toLowerCase();
  if (value == 'active' || value == 'playing' || value == 'jugando' || value == 'en_curso') return Colors.green.shade700;
  if (value == 'finished' || value == 'finalizado') return Colors.blueGrey;
  return Colors.amber.shade700;
}

/// ES: Convierte un color guardado o nombre de uniforme a Color de Flutter.
/// EN: Converts a stored color or uniform name into a Flutter Color.
Color _teamColorFromValue(dynamic value, Color fallback) {
  if (value is int) return Color(value);
  if (value is String) {
    final normalized = value.replaceFirst('#', '');
    final hex = int.tryParse(normalized, radix: 16);
    if (hex != null) return Color(normalized.length <= 6 ? 0xFF000000 | hex : hex);
    final named = <String, Color>{
      'rojo': Colors.red, 'azul': Colors.blue, 'verde': Colors.green,
      'amarillo': Colors.yellow, 'naranja': Colors.orange, 'negro': Colors.black,
      'blanco': Colors.white, 'morado': Colors.purple,
    };
    return named[value.toLowerCase()] ?? fallback;
  }
  return fallback;
}

/// ES: Resuelve el nombre del equipo desde la inscripción o un valor alternativo.
/// EN: Resolves a team name from its registration or a fallback value.
String _registrationTeamName(Map<String, dynamic>? registration, dynamic fallback) {
  if (registration == null) return fallback.toString();
  return registration['teamName']?.toString() ?? registration['clubName']?.toString() ?? registration['name']?.toString() ?? fallback.toString();
}

/// ES: Genera una clave estable para agrupar partidos por fecha.
/// EN: Generates a stable key for grouping matches by date.
String _matchDateKey(dynamic value) {
  if (value is Timestamp) return value.toDate().toIso8601String();
  return value?.toString() ?? 'Fecha por definir';
}

/// ES: Convierte una clave de fecha en una etiqueta legible.
/// EN: Converts a date key into a readable label.
String _matchDateLabel(String value) {
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value;
  return '${_weekdayName(parsed.weekday)} ${parsed.day} de ${_monthName(parsed.month)}';
}

/// ES: Extrae la hora desde una fecha o muestra un texto alternativo.
/// EN: Extracts the time from a date value or returns a fallback label.
String _matchTimeLabel(dynamic value) {
  final date = value is Timestamp ? value.toDate() : DateTime.tryParse(value?.toString() ?? '');
  if (date != null) return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  return 'Hora por definir';
}

/// ES: Devuelve el nombre en español del día de la semana.
/// EN: Returns the Spanish name of the weekday.
String _weekdayName(int weekday) => const ['', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'][weekday];

/// ES: Devuelve el nombre en español del mes indicado.
/// EN: Returns the Spanish name of the specified month.
String _monthName(int month) => const [
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
    ][month - 1];

/// ES: Métrica compacta que puede abrir una pantalla de detalle.
/// EN: Compact metric that can open a detailed screen.
class _StatCard extends StatelessWidget {
  /// ES: Crea la tarjeta de métrica y su acción opcional.
  /// EN: Creates the metric card and its optional action.
  const _StatCard({required this.label, required this.value, this.onTap});
  final String label;
  final String value;
  final VoidCallback? onTap;

  /// ES: Construye la tarjeta con etiqueta, valor y acción.
  /// EN: Builds the card with its label, value, and action.
  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: Text(label, style: Theme.of(context).textTheme.bodySmall)),
                const SizedBox(width: 8),
                Text(value, style: Theme.of(context).textTheme.titleLarge),
                if (onTap != null) const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.chevron_right, size: 18)),
              ],
            ),
          ),
        ),
      );
}

/// ES: Lista las inscripciones de equipo aprobadas del torneo.
/// EN: Lists approved team registrations for the tournament.
class _ApprovedTeamsScreen extends StatelessWidget {
  /// ES: Crea la pantalla de equipos aprobados.
  /// EN: Creates the approved teams screen.
  const _ApprovedTeamsScreen({required this.tournament});

  final Tournament tournament;

  /// ES: Observa inscripciones aprobadas y permite abrir cada ficha.
  /// EN: Watches approved registrations and opens each team profile.
  @override
  Widget build(BuildContext context) {
    final stream = TeamRepository().watchTournamentRegistrationDocuments(tournament.id);

    return Scaffold(
      appBar: AppBar(title: const Text('Equipos inscritos')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('No se pudieron cargar los equipos.'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final teams = snapshot.data!.docs;
          if (teams.isEmpty) {
            return const Center(child: Text('Aún no hay equipos aprobados.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: teams.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final data = teams[index].data();
              final players = data['players'] as List?;
              final name = data['teamName']?.toString().trim().isNotEmpty == true
                  ? data['teamName'].toString()
                  : 'Equipo sin nombre';
              final uniformColor = data['uniformColor']?.toString();
              final teamColor = _uniformColor(uniformColor);
              return Card(
                margin: EdgeInsets.zero,
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TeamDetailScreen(
                        tournament: tournament,
                        registrationId: teams[index].id,
                        registration: data,
                        teamColor: teamColor,
                      ),
                    ),
                  ),
                  leading: CircleAvatar(
                    backgroundColor: teamColor,
                    foregroundColor: _contrastColor(teamColor),
                    child: Text(name.substring(0, 1).toUpperCase()),
                  ),
                  title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('${players?.length ?? data['playerCount'] ?? 0} jugadores'),
                  trailing: const Icon(Icons.chevron_right),
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// ES: Convierte el nombre del uniforme a su color visual.
  /// EN: Converts a uniform name into its display color.
  Color _uniformColor(String? value) {
    switch (value?.trim().toLowerCase()) {
      case 'verde':
        return Colors.green;
      case 'azul':
        return Colors.blue;
      case 'rojo':
        return Colors.red;
      case 'naranja':
        return Colors.orange;
      case 'amarillo':
        return Colors.amber;
      case 'blanco':
        return Colors.white;
      case 'negro':
        return Colors.black;
      default:
        return Colors.grey;
    }
  }

  /// ES: Elige texto negro o blanco según el contraste del fondo.
  /// EN: Chooses black or white text based on background contrast.
  Color _contrastColor(Color color) => color.computeLuminance() > 0.5 ? Colors.black : Colors.white;
}

/// ES: Título de sección con una acción opcional al final.
/// EN: Section heading with an optional trailing action.
class _SectionTitle extends StatelessWidget {
  /// ES: Crea un título y, opcionalmente, un botón de acción.
  /// EN: Creates a heading and an optional action button.
  const _SectionTitle({required this.title, this.action, this.onAction});
  final String title;
  final String? action;
  final VoidCallback? onAction;

  /// ES: Construye el título y su acción opcional.
  /// EN: Builds the heading and its optional action.
  @override
  Widget build(BuildContext context) => Row(children: [Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)), if (action != null) TextButton(onPressed: onAction, child: Text(action!))]);
}

/// ES: Muestra una vista resumida del líder de la tabla.
/// EN: Shows a summary of the current standings leader.
class _StandingsSummary extends StatelessWidget {
  /// ES: Crea el resumen para el torneo indicado.
  /// EN: Creates the standings summary for the supplied tournament.
  const _StandingsSummary({required this.tournament});
  final Tournament tournament;

  /// ES: Presenta el líder y sus puntos de la tabla calculada.
  /// EN: Displays the leader and points from the calculated standings.
  @override
  Widget build(BuildContext context) => _StandingsData(
        tournament: tournament,
        builder: (rows) {
          final leader = rows.isEmpty ? null : rows.first;
          return Card(
            child: ListTile(
              leading: const CircleAvatar(child: Text('1')),
              title: Text(leader?.team ?? 'Aún no hay equipos clasificados', style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: leader == null ? null : Text('${leader.points} pts · DG ${leader.goalDifference}'),
            ),
          );
        },
      );
}

/// ES: Escucha inscripciones y partidos y calcula las posiciones.
/// EN: Watches registrations and matches and calculates standings.
class _StandingsData extends StatelessWidget {
  /// ES: Crea el proveedor de tabla con el builder de presentación.
  /// EN: Creates the standings provider with its presentation builder.
  const _StandingsData({required this.tournament, required this.builder});
  final Tournament tournament;
  final Widget Function(List<StandingEntry> rows) builder;

  /// ES: Combina streams de Firestore y entrega filas al builder.
  /// EN: Combines Firestore streams and passes standings rows to the builder.
  @override
  Widget build(BuildContext context) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('tournaments').doc(tournament.id).collection('registrations').snapshots(),
        builder: (context, registrations) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('tournaments').doc(tournament.id).collection('matches').snapshots(),
          builder: (context, matches) {
            if (registrations.hasError || matches.hasError) return const Text('No se pudo cargar la tabla.');
            if (!registrations.hasData || !matches.hasData) return const Center(child: CircularProgressIndicator());
            return builder(calculateStandings(registrations: registrations.data!.docs, matches: matches.data!.docs));
          },
        ),
      );
}

/// ES: Muestra la tabla completa de posiciones del torneo.
/// EN: Displays the complete tournament standings table.
class _FullStandingsScreen extends StatelessWidget {
  /// ES: Crea la pantalla de posiciones completas.
  /// EN: Creates the full standings screen.
  const _FullStandingsScreen({required this.tournament});
  final Tournament tournament;

  /// ES: Renderiza todas las filas de posiciones y estadísticas.
  /// EN: Renders all standings rows and statistics.
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Tabla de posiciones')),
        body: _StandingsData(
          tournament: tournament,
          builder: (rows) {
            if (rows.isEmpty) return const Center(child: Text('Aún no hay equipos clasificados.'));
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              itemCount: rows.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, index) {
                if (index == 0) {
                  return Card(child: Padding(padding: const EdgeInsets.all(14), child: Text('PJ: jugados · PG/PE/PP: ganados/empatados/perdidos · GF/GC: goles a favor/en contra · DG: diferencia de goles', style: Theme.of(context).textTheme.bodySmall)));
                }
                final row = rows[index - 1];
                return _StandingRow(position: '${index}', team: row.team, points: '${row.points} pts', played: row.played, wins: row.wins, draws: row.draws, losses: row.losses, goalsFor: row.goalsFor, goalsAgainst: row.goalsAgainst);
              },
            );
          },
        ),
      );
}

/// ES: Fila de tabla con posición, puntos y rendimiento del equipo.
/// EN: Standings row showing rank, points, and team performance.
class _StandingRow extends StatelessWidget {
  /// ES: Crea una fila de posiciones con sus métricas.
  /// EN: Creates a standings row with its metrics.
  const _StandingRow({required this.position, required this.team, required this.points, this.played = 0, this.wins = 0, this.draws = 0, this.losses = 0, this.goalsFor = 0, this.goalsAgainst = 0});
  final String position;
  final String team;
  final String points;
  final int played;
  final int wins;
  final int draws;
  final int losses;
  final int goalsFor;
  final int goalsAgainst;

  /// ES: Construye la fila con partidos, resultados y goles.
  /// EN: Builds the row with matches, results, and goals.
  @override
  Widget build(BuildContext context) {
    final goalDifference = goalsFor - goalsAgainst;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            SizedBox(width: 24, child: Text(position, style: const TextStyle(fontWeight: FontWeight.bold))),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(team, overflow: TextOverflow.ellipsis), Text('PJ $played · PG $wins · PE $draws · PP $losses · GF $goalsFor · GC $goalsAgainst · DG $goalDifference', style: Theme.of(context).textTheme.labelSmall, maxLines: 2, overflow: TextOverflow.ellipsis)])),
            const SizedBox(width: 8),
            Text(points, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

/// ES: Calcula los líderes de goles y los porteros con menos goles recibidos.
/// EN: Calculates top scorers and goalkeepers with the fewest goals conceded.
class _Highlights extends StatelessWidget {
  /// ES: Crea la sección de destacados del torneo.
  /// EN: Creates the tournament highlights section.
  const _Highlights({required this.tournament});
  final Tournament tournament;

  /// ES: Agrega eventos y marcadores y presenta los líderes calculados.
  /// EN: Aggregates match events and scores, then displays the leaders.
  @override
  Widget build(BuildContext context) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('tournaments').doc(tournament.id).collection('matches').snapshots(),
        builder: (context, matchSnapshot) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('tournaments').doc(tournament.id).collection('registrations').snapshots(),
          builder: (context, registrationSnapshot) {
            final registrations = registrationSnapshot.data?.docs ?? const [];
            final matches = matchSnapshot.data?.docs ?? const [];
            final playerInfo = <String, Map<String, dynamic>>{};
            for (final registration in registrations) {
              final players = registration.data()['players'];
              if (players is! List) continue;
              for (final rawPlayer in players) {
                if (rawPlayer is! Map) continue;
                final player = Map<String, dynamic>.from(rawPlayer);
                final key = (player['id'] ?? player['uid'] ?? player['playerId'] ?? player['name'] ?? player['nombre'])?.toString().trim();
                if (key != null && key.isNotEmpty) playerInfo[key] = player;
              }
            }
            final goals = <String, int>{};
            final goalsByTeam = <String, int>{};
            for (final match in matches) {
              final data = match.data();
              final status = data['status']?.toString().toLowerCase();
              if (!['finished', 'finished_match', 'completed', 'complete', 'finalizado', 'finalizada'].contains(status)) continue;
              final events = data['finalEvents'] ?? data['events'];
              if (events is List) {
                for (final rawEvent in events) {
                  if (rawEvent is! Map || rawEvent['type']?.toString() != 'goal') continue;
                  final name = (rawEvent['playerName'] ?? rawEvent['player'] ?? 'Jugador').toString();
                  goals[name] = (goals[name] ?? 0) + 1;
                }
              }
              final home = data['homeTeamId']?.toString() ?? data['homeTeam']?.toString();
              final away = data['awayTeamId']?.toString() ?? data['awayTeam']?.toString();
              final homeGoals = int.tryParse('${data['finalHomeScore'] ?? data['homeScore'] ?? 0}') ?? 0;
              final awayGoals = int.tryParse('${data['finalAwayScore'] ?? data['awayScore'] ?? 0}') ?? 0;
              String teamKey(Object value) => value.toString().trim().toLowerCase();
              if (home != null) goalsByTeam[teamKey(home)] = (goalsByTeam[teamKey(home)] ?? 0) + awayGoals;
              if (away != null) goalsByTeam[teamKey(away)] = (goalsByTeam[teamKey(away)] ?? 0) + homeGoals;
            }
            String bestBy(bool female) {
              final eligible = goals.entries.where((entry) {
                final player = playerInfo[entry.key];
                final gender = player?['gender'] ?? player?['genero'] ?? player?['sex'];
                return gender == null || gender.toString().toLowerCase().contains(female ? 'fem' : 'masc');
              }).toList()..sort((a, b) => b.value.compareTo(a.value));
              return eligible.isEmpty ? 'Sin datos' : '${eligible.first.key} · ${eligible.first.value} goles';
            }
            String bestGoalkeeper() {
              final candidates = <String, int>{};
              for (final registration in registrations) {
                final data = registration.data();
                final players = data['players'];
                if (players is! List) continue;
                String normalizeTeam(Object value) => value.toString().trim().toLowerCase();
                final teamKey = normalizeTeam(data['teamId'] ?? data['id'] ?? data['teamName'] ?? registration.id);
                final received = goalsByTeam[teamKey] ?? goalsByTeam[normalizeTeam(data['teamName'] ?? '')] ?? goalsByTeam[normalizeTeam(registration.id)] ?? 0;
                for (final rawPlayer in players) {
                  if (rawPlayer is! Map) continue;
                  final role = '${rawPlayer['position'] ?? rawPlayer['role'] ?? rawPlayer['posicion'] ?? ''}'.toLowerCase();
                  if (role.contains('arqu') || role.contains('port')) {
                    final name = (rawPlayer['name'] ?? rawPlayer['nombre'] ?? rawPlayer['displayName'] ?? 'Arquero').toString();
                    candidates[name] = received;
                  }
                }
              }
              if (candidates.isEmpty) return 'Sin datos';
              final best = candidates.entries.toList()..sort((a, b) => a.value.compareTo(b.value));
              return '${best.first.key} · ${best.first.value} goles recibidos';
            }
            return Column(children: [
              if (tournament.shouldShowMaleScorers)
                _HighlightCard(
                  icon: Icons.emoji_events_outlined,
                  title: 'Goleador masculino',
                  subtitle: 'Goles acumulados en partidos finalizados',
                  value: bestBy(false),
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => _FullHighlightScreen(tournament: tournament, type: _HighlightType.maleScorers))),
                ),
              if (tournament.shouldShowFemaleScorers)
                _HighlightCard(
                  icon: Icons.emoji_events_outlined,
                  title: 'Goleadora femenina',
                  subtitle: 'Goles acumulados en partidos finalizados',
                  value: bestBy(true),
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => _FullHighlightScreen(tournament: tournament, type: _HighlightType.femaleScorers))),
                ),
              _HighlightCard(
                icon: Icons.shield_outlined,
                title: 'Valla menos vencida',
                subtitle: 'Menos goles recibidos durante el torneo',
                value: bestGoalkeeper(),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => _FullHighlightScreen(tournament: tournament, type: _HighlightType.goalkeepers))),
              ),
            ]);
          },
        ),
      );
}

/// ES: Tipos de tablas destacadas que se pueden abrir.
/// EN: Types of highlight tables that can be opened.
enum _HighlightType { maleScorers, femaleScorers, goalkeepers }

/// ES: Elemento de una tabla de goleadores o porteros destacados.
/// EN: Entry in a top scorers or goalkeepers table.
class _HighlightEntry {
  /// ES: Crea una fila con nombre, valor y equipo opcional.
  /// EN: Creates a row with a name, value, and optional team.
  const _HighlightEntry({required this.name, required this.value, this.team});
  final String name;
  final int value;
  final String? team;
}

/// ES: Muestra el listado completo de una categoría destacada.
/// EN: Displays the complete list for a selected highlight category.
class _FullHighlightScreen extends StatelessWidget {
  /// ES: Crea la tabla completa para el tipo de destacado seleccionado.
  /// EN: Creates the full table for the selected highlight type.
  const _FullHighlightScreen({required this.tournament, required this.type});
  final Tournament tournament;
  final _HighlightType type;

  /// ES: Convierte cualquier valor opcional en texto recortado.
  /// EN: Converts an optional value into trimmed text.
  String _text(Object? value) => value?.toString().trim() ?? '';

  /// ES: Obtiene y normaliza el género registrado de un jugador.
  /// EN: Reads and normalizes a player's stored gender.
  String _gender(Map<String, dynamic> player) => _text(player['gender'] ?? player['genero'] ?? player['sex']).toLowerCase();

  /// ES: Busca el nombre del jugador en los campos admitidos.
  /// EN: Reads a player's name from supported fields.
  String _playerName(Map<String, dynamic> player) => _text(player['name'] ?? player['nombre'] ?? player['displayName'] ?? player['fullName']);

  /// ES: Obtiene la clave estable usada para asociar eventos al jugador.
  /// EN: Gets the stable key used to associate events with a player.
  String _playerKey(Map<String, dynamic> player) => _text(player['id'] ?? player['uid'] ?? player['playerId'] ?? _playerName(player));

  /// ES: Resuelve el nombre del equipo o usa el texto alternativo.
  /// EN: Resolves the team name or uses the supplied fallback.
  String _teamName(Map<String, dynamic> team, String fallback) => _text(team['teamName'] ?? team['name'] ?? team['displayName']) .isEmpty ? fallback : _text(team['teamName'] ?? team['name'] ?? team['displayName']);

  /// ES: Lee inscripciones y partidos y calcula las filas del ranking.
  /// EN: Loads registrations and matches and calculates ranking entries.
  Future<List<_HighlightEntry>> _loadEntries() async {
    final ref = FirebaseFirestore.instance.collection('tournaments').doc(tournament.id);
    final registrationSnapshot = await ref.collection('registrations').get();
    final matchSnapshot = await ref.collection('matches').get();
    final players = <String, Map<String, dynamic>>{};
    final playerTeams = <String, String>{};
    final teamGoalsAgainst = <String, int>{};
    final teamNames = <String, String>{};
    final entries = <String, int>{};

    /// ES: Normaliza IDs y nombres de equipo para cruzar datos de partidos.
    /// EN: Normalizes team IDs and names to match data across documents.
    String normalize(Object? value) => value.toString().trim().toLowerCase();

    /// ES: Obtiene alias de equipo almacenados como texto o mapa.
    /// EN: Extracts team aliases stored as text or a map.
    List<String> teamIdentifiers(Object? raw) {
      if (raw is Map) return [raw['id'], raw['teamId'], raw['registrationId'], raw['name'], raw['teamName']].where((v) => v != null && _text(v).isNotEmpty).map(_text).toList();
      return _text(raw).isEmpty ? const [] : [_text(raw)];
    }

    for (final registration in registrationSnapshot.docs) {
      final data = registration.data();
      final name = _teamName(data, registration.id);
      final identifiers = {...teamIdentifiers(registration.id), ...teamIdentifiers(data['teamId']), ...teamIdentifiers(data['id']), ...teamIdentifiers(data['teamName']), ...teamIdentifiers(data['team'])};
      for (final identifier in identifiers) teamNames[normalize(identifier)] = name;
      final rawPlayers = data['players'];
      if (rawPlayers is! List) continue;
      for (final raw in rawPlayers) {
        if (raw is! Map) continue;
        final player = Map<String, dynamic>.from(raw);
        final key = _playerKey(player);
        if (key.isEmpty) continue;
        players[key] = player;
        playerTeams[key] = name;
        if (type != _HighlightType.goalkeepers) entries[key] = 0;
      }
    }

    for (final match in matchSnapshot.docs) {
      final data = match.data();
      final status = normalize(data['status']);
      if (!{'finished', 'finalizado', 'finalizada', 'completed'}.contains(status)) continue;
      final homeIds = teamIdentifiers(data['homeTeamId'] ?? data['homeTeam'] ?? data['homeTeamName']);
      final awayIds = teamIdentifiers(data['awayTeamId'] ?? data['awayTeam'] ?? data['awayTeamName']);
      final homeKey = homeIds.map(normalize).firstWhere((id) => teamNames.containsKey(id), orElse: () => homeIds.isEmpty ? '' : normalize(homeIds.first));
      final awayKey = awayIds.map(normalize).firstWhere((id) => teamNames.containsKey(id), orElse: () => awayIds.isEmpty ? '' : normalize(awayIds.first));
      final homeGoals = (data['finalHomeScore'] as num?)?.toInt() ?? int.tryParse(_text(data['finalHomeScore'] ?? data['homeScore'])) ?? 0;
      final awayGoals = (data['finalAwayScore'] as num?)?.toInt() ?? int.tryParse(_text(data['finalAwayScore'] ?? data['awayScore'])) ?? 0;
      teamGoalsAgainst[homeKey] = (teamGoalsAgainst[homeKey] ?? 0) + awayGoals;
      teamGoalsAgainst[awayKey] = (teamGoalsAgainst[awayKey] ?? 0) + homeGoals;
      final rawEvents = data['finalEvents'] ?? data['events'];
      if (rawEvents is! List || type == _HighlightType.goalkeepers) continue;
      for (final raw in rawEvents) {
        if (raw is! Map || _text(raw['type']).toLowerCase() != 'goal') continue;
        final key = _text(raw['player'] ?? raw['playerId'] ?? raw['uid']);
        final name = _text(raw['playerName'] ?? raw['name']);
        final matchingKey = players.keys.firstWhere((candidate) => candidate == key || _text(players[candidate]?['name'] ?? players[candidate]?['nombre']) == name, orElse: () => '');
        if (matchingKey.isNotEmpty) entries[matchingKey] = (entries[matchingKey] ?? 0) + 1;
      }
    }

    if (type == _HighlightType.goalkeepers) {
      for (final entry in players.entries) {
        final role = _text(entry.value['position'] ?? entry.value['role'] ?? entry.value['posicion']).toLowerCase();
        if (role.contains('arqu') || role.contains('port') || role.contains('goalkeeper')) entries[entry.key] = teamGoalsAgainst.entries.firstWhere((team) => teamNames[team.key] == playerTeams[entry.key], orElse: () => const MapEntry('', 0)).value;
      }
    }
    final female = type == _HighlightType.femaleScorers;
    return entries.entries
        .where((entry) {
          final gender = _gender(players[entry.key] ?? const {});
          if (type == _HighlightType.goalkeepers) return true;
          if (gender.isEmpty) return true;
          return female ? gender.contains('fem') || gender.contains('muj') : gender.contains('masc') || gender.contains('hom') || gender == 'm';
        })
        .map((entry) => _HighlightEntry(name: _playerName(players[entry.key] ?? const {}), value: entry.value, team: playerTeams[entry.key]))
        .where((entry) => entry.name.isNotEmpty)
        .toList()
      ..sort((a, b) => type == _HighlightType.goalkeepers ? a.value.compareTo(b.value) : b.value.compareTo(a.value));
  }

  /// ES: Muestra carga, tabla vacía o filas del ranking seleccionado.
  /// EN: Displays loading, an empty state, or rows for the selected ranking.
  @override
  Widget build(BuildContext context) {
    final title = switch (type) {
      _HighlightType.maleScorers => 'Goleadores masculinos',
      _HighlightType.femaleScorers => 'Goleadoras femeninas',
      _HighlightType.goalkeepers => 'Valla menos vencida',
    };
    final female = type == _HighlightType.femaleScorers;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: FutureBuilder<List<_HighlightEntry>>(
        future: _loadEntries(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final rows = snapshot.data!;
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: rows.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, index) => Card(child: ListTile(leading: CircleAvatar(child: Text('${index + 1}')), title: Text(rows[index].name), subtitle: Text(rows[index].team ?? ''), trailing: Text(type == _HighlightType.goalkeepers ? '${rows[index].value} GC' : '${rows[index].value} goles', style: const TextStyle(fontWeight: FontWeight.bold)))),
          );
        },
      ),
    );
  }
}

/// ES: Tarjeta de resumen que abre la tabla completa del destacado.
/// EN: Summary card that opens the full highlight table.
class _HighlightCard extends StatelessWidget {
  /// ES: Crea la tarjeta de destacado con acción opcional.
  /// EN: Creates a highlight card with an optional action.
  const _HighlightCard({required this.icon, required this.title, required this.subtitle, required this.value, this.onPressed});
  final IconData icon;
  final String title;
  final String subtitle;
  final String value;
  final VoidCallback? onPressed;

  /// ES: Construye la tarjeta con icono, resumen y valor calculado.
  /// EN: Builds the card with icon, summary, and calculated value.
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final hasData = value != 'Sin datos';
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: colors.primary.withValues(alpha: .15), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: colors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
                    const SizedBox(height: 6),
                    Text(
                      value,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700, color: hasData ? colors.onSurface : colors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: colors.onSurfaceVariant, semanticLabel: 'Ver tabla completa'),
            ],
          ),
        ),
      ),
    );
  }
}

/// ES: Presenta categorías, ramas y fechas principales del torneo.
/// EN: Presents the tournament's categories, branches, and key dates.
class _DetailsCard extends StatelessWidget {
  /// ES: Crea la tarjeta de información del torneo.
  /// EN: Creates the tournament details card.
  const _DetailsCard({required this.tournament});
  final Tournament tournament;

  /// ES: Construye los datos descriptivos del torneo.
  /// EN: Builds the tournament's descriptive details.
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Categorías y ramas', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: tournament.categories.map((category) => Chip(label: Text(formatCategory(category)))).toList()),
            const SizedBox(height: 8),
            Text('Inscripción pública: ${tournament.publicRegistration ? 'Sí' : 'No'}'),
            Text('Fecha de inicio: ${tournament.startDate == null ? 'Pendiente' : _date(tournament.startDate!)}'),
            Text('Fecha de finalización: ${tournament.endDate == null ? 'No definida' : _date(tournament.endDate!)}'),
          ]),
        ),
      );

  /// ES: Da formato día/mes/año a una fecha.
  /// EN: Formats a date as day/month/year.
  String _date(DateTime value) => '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
}

/// ES: Combina el estado del torneo con los partidos activos en tiempo real.
/// EN: Combines tournament status with live match activity.
class _TournamentLiveStatus extends StatelessWidget {
  /// ES: Crea el indicador con el estado alternativo del torneo.
  /// EN: Creates the indicator with the tournament's fallback status.
  const _TournamentLiveStatus({required this.tournament, required this.fallbackStatus});
  final Tournament tournament;
  final String fallbackStatus;

  /// ES: Observa partidos y muestra el estado actual del torneo.
  /// EN: Watches matches and displays the tournament's current status.
  @override
  Widget build(BuildContext context) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('tournaments').doc(tournament.id).collection('matches').snapshots(),
        builder: (context, snapshot) {
          final statuses = snapshot.data?.docs.map((doc) => (doc.data()['status'] ?? '').toString().toLowerCase()).toList() ?? const <String>[];
          final hasLive = statuses.any((value) => ['active', 'playing', 'jugando', 'en_curso', 'live', 'tiempo_muerto'].contains(value));
  // ES: El estado del torneo manda; terminar un partido no finaliza el torneo.
  // EN: Tournament status is authoritative; finishing one match does not end it.
  final status = hasLive ? 'En curso' : _formatTournamentStatus(fallbackStatus);
          return _InfoBadge(label: status, color: _tournamentStatusColor(status.toLowerCase()));
        },
      );
}

/// ES: Convierte estados internos del torneo en etiquetas visibles.
/// EN: Converts internal tournament statuses into display labels.
String _formatTournamentStatus(String status) {
  final normalized = status.trim().toLowerCase();
  if (normalized == 'active' || normalized == 'playing' || normalized == 'jugando' || normalized == 'en_curso' || normalized == 'en curso') return 'En curso';
  if (normalized == 'finished' || normalized == 'finalized' || normalized == 'finalizado' || normalized == 'finalizada') return 'Finalizado';
  return 'Por iniciar';
}

/// ES: Insignia de color para mostrar un estado o formato.
/// EN: Colored badge for displaying a status or format.
class _InfoBadge extends StatelessWidget {
  /// ES: Crea una insignia con etiqueta y color.
  /// EN: Creates a badge with a label and color.
  const _InfoBadge({required this.label, required this.color});
  final String label;
  final Color color;

  /// ES: Construye la insignia con fondo y texto coordinados.
  /// EN: Builds the badge with matching background and text colors.
  @override
  Widget build(BuildContext context) => DecoratedBox(decoration: BoxDecoration(color: color.withValues(alpha: .18), borderRadius: BorderRadius.circular(8)), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600))));
}

/// ES: Convierte identificadores de formato en etiquetas legibles.
/// EN: Converts format identifiers into readable labels.
String _formatLabel(String value) => value == 'todos_contra_todos' ? 'Todos contra todos' : value == 'por_grupos' ? 'Por grupos' : value;
