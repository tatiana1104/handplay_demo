import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../widgets/match_status_label.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/route_names.dart';

import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../../shared/widgets/app_bottom_navigation_bar.dart';

/// ES: Calendario global de partidos agrupados por fecha.
/// EN: Global match calendar grouped by date.
class CalendarScreen extends StatelessWidget {
  /// ES: Crea el calendario de partidos.
  /// EN: Creates the match calendar.
  const CalendarScreen({super.key});

  /// ES: Comprueba si la sesión pertenece a un usuario no público.
  /// EN: Checks whether the session belongs to a non-public user.
  bool _isRealAuthenticated(BuildContext context) {
    final state = context.watch<AuthBloc>().state;
    if (state is! AuthAuthenticated) return false;
    return !state.user.roles.any((role) => role == 'publico' || role == 'public');
  }

  /// ES: Combina partidos e inscripciones para mostrar el calendario.
  /// EN: Combines matches and registrations to display the calendar.
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

/// ES: Agrupa en una sección los partidos de una fecha.
/// EN: Groups the matches for one date into a section.
class _CalendarDay extends StatelessWidget {
  /// ES: Crea una sección diaria con sus partidos.
  /// EN: Creates a daily section with its matches.
  const _CalendarDay({required this.title, required this.matches});
  final String title;
  final List<Map<String, dynamic>> matches;

  /// ES: Construye tarjetas navegables para los partidos del día.
  /// EN: Builds navigable cards for the day's matches.
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
                            color: matchStatusColor(context, match['status']?.toString()).withValues(alpha: .16),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: matchStatusColor(context, match['status']?.toString()).withValues(alpha: .28)),
                          ),
                          child: Text(
                            matchStatusLabel(match['status']?.toString()),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: matchStatusColor(context, match['status']?.toString()), fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(child: _TeamSide(label: 'LOCAL', name: _name(match, true), color: _color(match['homeTeamColor'], Colors.green))),
                        Column(children: [
                          if (match['status']?.toString().toLowerCase() == 'finished' || match['status']?.toString().toLowerCase() == 'finalizado')
                            Text('${match['homeScore'] ?? match['finalHomeScore'] ?? 0} - ${match['awayScore'] ?? match['finalAwayScore'] ?? 0}', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                          if (match['status']?.toString().toLowerCase() != 'finished' && match['status']?.toString().toLowerCase() != 'finalizado')
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

  /// ES: Resuelve el nombre del equipo local o visitante.
  /// EN: Resolves the home or away team's display name.
  String _name(Map<String, dynamic> match, bool home) => match[home ? 'homeTeamName' : 'awayTeamName']?.toString() ?? match[home ? 'homeTeam' : 'awayTeam']?.toString() ?? (home ? 'Equipo local' : 'Equipo visitante');

  /// ES: Traduce el estado del partido a una etiqueta resumida.
  /// EN: Converts match status into a short display label.
  String _statusLabel(String? status) => switch (status?.trim().toLowerCase()) {
        'live' || 'en vivo' || 'playing' || 'jugando' => 'Jugando',
        'finished' || 'finalizado' || 'completed' => 'Finalizado',
        _ => 'Programado',
      };

  /// ES: Convierte un color almacenado o nombre de uniforme a Color.
  /// EN: Converts a stored color or uniform name into a Color.
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

/// ES: Relaciona un equipo del partido con su inscripción usando IDs y nombres.
/// EN: Matches a team in a fixture to its registration using IDs and names.
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

/// ES: Obtiene el nombre de equipo de una inscripción o usa el alternativo.
/// EN: Gets the team name from a registration or uses a fallback.
String _teamName(Map<String, dynamic>? registration, dynamic fallback) {
    if (registration == null) return fallback.toString();
    final name = registration['teamName'] ?? registration['name'] ?? registration['clubName'] ?? registration['team'];
    return name?.toString().trim().isNotEmpty == true ? name.toString().trim() : fallback.toString();
  }

/// ES: Convierte un valor guardado en fecha para ordenar los partidos.
/// EN: Converts a stored value into a date for sorting matches.
DateTime _dateValue(dynamic value) => value is Timestamp ? value.toDate() : DateTime.tryParse(value?.toString() ?? '') ?? DateTime(9999);

/// ES: Formatea una fecha como nombre del día y fecha legible.
/// EN: Formats a date as a weekday and readable calendar date.
String _dateLabel(dynamic value) {
  final date = value is Timestamp ? value.toDate() : DateTime.tryParse(value?.toString() ?? '');
  if (date == null) return 'Fecha por definir';
  const weekdays = ['', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
  const months = ['', 'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];
  return '${weekdays[date.weekday]} ${date.day} de ${months[date.month]}';
}

/// ES: Extrae la hora de una fecha programada o devuelve una alternativa.
/// EN: Extracts the scheduled time or returns a fallback label.
String _time(dynamic value) {
  final date = value is Timestamp ? value.toDate() : DateTime.tryParse(value?.toString() ?? '');
  return date == null ? 'Hora por definir' : '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}


/// ES: Muestra el nombre y color del equipo en un lado del marcador.
/// EN: Shows a team's name and color on one side of the fixture.
class _TeamSide extends StatelessWidget {
  /// ES: Crea la etiqueta de local o visitante.
  /// EN: Creates a home or away team label.
  const _TeamSide({required this.label, required this.name, required this.color, this.alignEnd = false});
  final String label;
  final String name;
  final Color color;
  final bool alignEnd;

  /// ES: Construye la etiqueta alineada según el lado del equipo.
  /// EN: Builds the label aligned for the team's side.
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
