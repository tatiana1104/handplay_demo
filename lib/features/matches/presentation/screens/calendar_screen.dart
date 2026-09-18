import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/route_names.dart';

import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../../shared/widgets/app_bottom_navigation_bar.dart';

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  bool _isRealAuthenticated(BuildContext context) {
    final state = context.watch<AuthBloc>().state;
    if (state is! AuthAuthenticated) return false;
    return !state.user.roles.any((role) => role == 'publico' || role == 'public');
  }

  @override
  Widget build(BuildContext context) {
    final matches = FirebaseFirestore.instance.collectionGroup('matches').snapshots();
    final registrations = FirebaseFirestore.instance.collectionGroup('registrations').snapshots();
    return Scaffold(
      appBar: AppBar(title: const Text('Calendario')),
      bottomNavigationBar: AppBottomNavigationBar(
        selectedIndex: 1,
        isAuthenticated: _isRealAuthenticated(context),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: matches,
        builder: (context, snapshot) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: registrations,
          builder: (context, registrationsSnapshot) {
          if (snapshot.hasError) {
            return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('No se pudo cargar el calendario. Publica las reglas de Firestore y verifica que el usuario haya iniciado sesión.', textAlign: TextAlign.center)));
          }
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final registrationById = <String, Map<String, dynamic>>{
            for (final doc in registrationsSnapshot.data?.docs ?? const []) ...{
              doc.id: doc.data(),
              if (doc.data()['id'] != null) doc.data()['id'].toString(): doc.data(),
              if (doc.data()['teamId'] != null) doc.data()['teamId'].toString(): doc.data(),
              if (doc.data()['teamUid'] != null) doc.data()['teamUid'].toString(): doc.data(),
              if (doc.data()['team'] != null) doc.data()['team'].toString(): doc.data(),
              if (doc.data()['uid'] != null) doc.data()['uid'].toString(): doc.data(),
              if (doc.data()['registrationId'] != null) doc.data()['registrationId'].toString(): doc.data(),
              if (doc.data()['teamUid'] != null) doc.data()['teamUid'].toString(): doc.data(),
            },
          };
          final docs = [...snapshot.data!.docs]..sort((a, b) => _dateValue(a.data()['date']).compareTo(_dateValue(b.data()['date'])));
          if (docs.isEmpty) return const Center(child: Text('No hay partidos programados.'));
          final grouped = <String, List<Map<String, dynamic>>>{};
          for (final doc in docs) {
            final data = Map<String, dynamic>.from(doc.data());
            data['matchId'] = doc.id;
            data['tournamentId'] = doc.reference.parent.parent?.id;
            final homeId = data['homeTeam']?.toString() ?? data['local']?.toString();
            final awayId = data['awayTeam']?.toString() ?? data['visitante']?.toString();
            final home = _findRegistration(registrationById, homeId, data, true);
            final away = _findRegistration(registrationById, awayId, data, false);
            data['homeTeamName'] = _teamName(home, data['homeTeamName'] ?? data['localName'] ?? 'Equipo local');
            data['awayTeamName'] = _teamName(away, data['awayTeamName'] ?? data['visitorName'] ?? 'Equipo visitante');
            data['homeTeamColor'] = home?['uniformColor'] ?? data['homeTeamColor'];
            data['awayTeamColor'] = away?['uniformColor'] ?? data['awayTeamColor'];
            grouped.putIfAbsent(_dateLabel(data['date']), () => []).add(data);
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: grouped.entries
                .map((entry) => _CalendarDay(title: entry.key, matches: entry.value))
                .toList(),
          );
          },
        ),
      ),
    );
  }
}

class _CalendarDay extends StatelessWidget {
  const _CalendarDay({required this.title, required this.matches});
  final String title;
  final List<Map<String, dynamic>> matches;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 7, top: 4),
            child: Text(title, style: Theme.of(context).textTheme.labelMedium),
          ),
          ...matches.map((match) => Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => context.go(RouteNames.liveMatch, extra: {...match, 'id': match['matchId'].toString()}),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Align(
                        alignment: Alignment.topRight,
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 120),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _statusColor(match['status']?.toString()),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            _statusLabel(match['status']?.toString()),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(child: _TeamSide(label: 'LOCAL', name: _name(match, true), color: _color(match['homeTeamColor'], Colors.green))),
                        Column(children: [
                          Text(_time(match['date']), style: const TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 3),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 105),
                            child: Text(
                              match['venue']?.toString() ?? 'Sede por definir',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                            ),
                          ),
                        ]),
                        Expanded(child: Align(alignment: Alignment.centerRight, child: _TeamSide(label: 'VISITANTE', name: _name(match, false), color: _color(match['awayTeamColor'], Colors.deepOrange), alignEnd: true))),
                      ]),
                    ],
                  ),
                ),
                ),
              )),
        ],
      );

  String _name(Map<String, dynamic> match, bool home) => match[home ? 'homeTeamName' : 'awayTeamName']?.toString() ?? match[home ? 'homeTeam' : 'awayTeam']?.toString() ?? (home ? 'Equipo local' : 'Equipo visitante');

  String _statusLabel(String? status) => switch (status?.trim().toLowerCase()) {
        'live' || 'en vivo' || 'playing' || 'jugando' => 'Jugando',
        'finished' || 'finalizado' || 'completed' => 'Finalizado',
        _ => 'Programado',
      };

  Color _statusColor(String? status) => switch (status?.trim().toLowerCase()) {
        'live' || 'en vivo' || 'playing' || 'jugando' => Colors.green.shade700,
        'finished' || 'finalizado' || 'completed' => Colors.blueGrey,
        _ => Colors.amber.shade700,
      };
  Color _color(dynamic value, Color fallback) {
    if (value is int) return Color(value);
    if (value is String) {
      final hex = int.tryParse(value.replaceFirst('#', ''), radix: 16);
      if (hex != null) return Color(value.replaceFirst('#', '').length <= 6 ? 0xFF000000 | hex : hex);
      const named = {'rojo': Colors.red, 'azul': Colors.blue, 'verde': Colors.green, 'amarillo': Colors.yellow, 'naranja': Colors.orange, 'morado': Colors.purple, 'negro': Colors.black, 'blanco': Colors.white};
      return named[value.toLowerCase()] ?? fallback;
    }
    return fallback;
  }
}

  Map<String, dynamic>? _findRegistration(Map<String, Map<String, dynamic>> registrations, String? teamId, Map<String, dynamic> match, bool home) {
    if (teamId != null && registrations[teamId] != null) return registrations[teamId];
    final storedName = match[home ? 'homeTeamName' : 'awayTeamName'] ?? match[home ? 'localName' : 'visitorName'];
    for (final registration in registrations.values) {
      final identifiers = [
        registration['id'], registration['registrationId'], registration['teamId'],
        registration['teamUid'], registration['uid'],
      ].where((value) => value != null).map((value) => value.toString());
      if (teamId != null && identifiers.contains(teamId)) return registration;
      final registrationName = registration['teamName'] ?? registration['clubName'] ?? registration['name'] ?? registration['team'];
      if (storedName != null && registrationName?.toString() == storedName.toString()) return registration;
    }
    return null;
  }

  String _teamName(Map<String, dynamic>? registration, dynamic fallback) {
    if (registration == null) return fallback.toString();
    final name = registration['teamName'] ?? registration['name'] ?? registration['clubName'] ?? registration['team'];
    return name?.toString().trim().isNotEmpty == true ? name.toString().trim() : fallback.toString();
  }

DateTime _dateValue(dynamic value) => value is Timestamp ? value.toDate() : DateTime.tryParse(value?.toString() ?? '') ?? DateTime(9999);

String _dateLabel(dynamic value) {
  final date = value is Timestamp ? value.toDate() : DateTime.tryParse(value?.toString() ?? '');
  if (date == null) return 'Fecha por definir';
  const weekdays = ['', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
  const months = ['', 'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];
  return '${weekdays[date.weekday]} ${date.day} de ${months[date.month]}';
}

String _time(dynamic value) {
  final date = value is Timestamp ? value.toDate() : DateTime.tryParse(value?.toString() ?? '');
  return date == null ? 'Hora por definir' : '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}


class _TeamSide extends StatelessWidget {
  const _TeamSide({required this.label, required this.name, required this.color, this.alignEnd = false});
  final String label;
  final String name;
  final Color color;
  final bool alignEnd;

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
