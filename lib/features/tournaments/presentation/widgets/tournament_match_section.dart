import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/route_names.dart';
import '../../../matches/data/match_repository.dart';
import '../../../matches/presentation/widgets/match_status_label.dart';
import '../screens/tournament_match_form_screen.dart';
import '../../domain/models/tournament_models.dart';

class TournamentMatchSection extends StatelessWidget {
  const TournamentMatchSection({required this.tournament, super.key});

  final Tournament tournament;

  @override
  Widget build(BuildContext context) {
    final isAdmin = FirebaseAuth.instance.currentUser?.uid == tournament.adminId;
    final stream = MatchRepository().watchTournamentMatchDocuments(tournament.id);
    final teamsStream = FirebaseFirestore.instance
        .collection('tournaments')
        .doc(tournament.id)
        .collection('registrations')
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: teamsStream,
          builder: (context, teamsSnapshot) {
            final matches = snapshot.data?.docs ?? const [];
            final teamsById = <String, Map<String, dynamic>>{
              for (final doc in teamsSnapshot.data?.docs ?? const []) doc.id: doc.data(),
            };

            if (matches.isEmpty) {
              return const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionTitle(title: 'Partidos'),
                  SizedBox(height: 8),
                  Card(
                    child: ListTile(title: Text('Aún no hay partidos programados.')),
                  ),
                ],
              );
            }

            final grouped = <String, List<Map<String, dynamic>>>{};
            for (final doc in matches) {
              final data = Map<String, dynamic>.from(doc.data());
              data['id'] = doc.id;
              final homeId = data['homeTeam']?.toString() ?? data['local']?.toString();
              final awayId = data['awayTeam']?.toString() ?? data['visitante']?.toString();
              final homeRegistration = teamsById[homeId];
              final awayRegistration = teamsById[awayId];
              data['homeTeamName'] = _registrationTeamName(
                homeRegistration,
                data['homeTeamName'] ?? homeId ?? 'Equipo local',
              );
              data['awayTeamName'] = _registrationTeamName(
                awayRegistration,
                data['awayTeamName'] ?? awayId ?? 'Equipo visitante',
              );
              data['homeTeamColor'] = homeRegistration?['uniformColor'] ?? data['homeTeamColor'];
              data['awayTeamColor'] = awayRegistration?['uniformColor'] ?? data['awayTeamColor'];

              final date = _matchDateKey(data['date'] ?? data['fecha']);
              grouped.putIfAbsent(date, () => []).add(data);
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionTitle(title: 'Partidos'),
                const SizedBox(height: 8),
                ...grouped.entries.map((entry) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 6, top: 4),
                        child: Text(
                          _matchDateLabel(entry.key),
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ),
                      ...entry.value.map((match) {
                        final home = match['homeTeamName']?.toString() ??
                            match['localName']?.toString() ??
                            match['homeTeam']?.toString() ??
                            match['local']?.toString() ??
                            'Equipo local';
                        final away = match['awayTeamName']?.toString() ??
                            match['visitorName']?.toString() ??
                            match['awayTeam']?.toString() ??
                            match['visitante']?.toString() ??
                            'Equipo visitante';
                        final homeColor = _teamColorFromValue(match['homeTeamColor'], Colors.green);
                        final awayColor = _teamColorFromValue(match['awayTeamColor'], Colors.deepOrange);
                        final time = match['time']?.toString() ?? _matchTimeLabel(match['date']);
                        final venue = match['venue']?.toString() ??
                            match['sede']?.toString() ??
                            match['cancha']?.toString() ??
                            'Sede por definir';
                        final status = match['status']?.toString() ?? 'scheduled';

                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          child: InkWell(
                            onTap: () => context.go(
                              RouteNames.liveMatch,
                              extra: {
                                ...match,
                                'id': match['id']?.toString() ?? '',
                                'tournamentId': tournament.id,
                              },
                            ),
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
                                        color: matchStatusColor(context, status).withValues(alpha: .16),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: matchStatusColor(context, status).withValues(alpha: .28),
                                        ),
                                      ),
                                      child: Text(
                                        matchStatusLabel(status),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: matchStatusColor(context, status),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _TeamMatchLabel(
                                          label: 'LOCAL',
                                          name: home,
                                          color: homeColor,
                                        ),
                                      ),
                                      Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (status.toLowerCase() == 'finished' ||
                                              status.toLowerCase() == 'finalizado')
                                            Text(
                                              '${match['homeScore'] ?? match['finalHomeScore'] ?? 0} - ${match['awayScore'] ?? match['finalAwayScore'] ?? 0}',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleMedium
                                                  ?.copyWith(fontWeight: FontWeight.w800),
                                            ),
                                          if (status.toLowerCase() != 'finished' &&
                                              status.toLowerCase() != 'finalizado')
                                            Text(
                                              time,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium
                                                  ?.copyWith(fontWeight: FontWeight.w600),
                                            ),
                                          const SizedBox(height: 3),
                                          ConstrainedBox(
                                            constraints: const BoxConstraints(maxWidth: 105),
                                            child: Text(
                                              venue,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              textAlign: TextAlign.center,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .labelSmall
                                                  ?.copyWith(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .onSurfaceVariant,
                                                  ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      Expanded(
                                        child: Align(
                                          alignment: Alignment.centerRight,
                                          child: _TeamMatchLabel(
                                            label: 'VISITANTE',
                                            name: away,
                                            color: awayColor,
                                            alignEnd: true,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
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
                                                builder: (_) => TournamentMatchFormScreen(
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
                                                content: const Text(
                                                  'Esta acción no se puede deshacer.',
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () => Navigator.pop(dialogContext, false),
                                                    child: const Text('Cancelar'),
                                                  ),
                                                  FilledButton(
                                                    onPressed: () => Navigator.pop(dialogContext, true),
                                                    child: const Text('Eliminar'),
                                                  ),
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
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  );
                }),
              ],
            );
          },
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _TeamMatchLabel extends StatelessWidget {
  const _TeamMatchLabel({
    required this.label,
    required this.name,
    required this.color,
    this.alignEnd = false,
  });

  final String label;
  final String name;
  final Color color;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!alignEnd)
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
              if (!alignEnd) const SizedBox(width: 4),
              Flexible(
                child: Text(
                  name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
              if (alignEnd) const SizedBox(width: 4),
              if (alignEnd)
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
            ],
          ),
        ],
      );
}

Color _teamColorFromValue(dynamic value, Color fallback) {
  if (value is int) return Color(value);
  if (value is String) {
    final normalized = value.replaceFirst('#', '');
    final hex = int.tryParse(normalized, radix: 16);
    if (hex != null) {
      return Color(normalized.length <= 6 ? 0xFF000000 | hex : hex);
    }
    final named = <String, Color>{
      'rojo': Colors.red,
      'azul': Colors.blue,
      'verde': Colors.green,
      'amarillo': Colors.yellow,
      'naranja': Colors.orange,
      'negro': Colors.black,
      'blanco': Colors.white,
      'morado': Colors.purple,
    };
    return named[value.toLowerCase()] ?? fallback;
  }
  return fallback;
}

String _registrationTeamName(Map<String, dynamic>? registration, dynamic fallback) {
  if (registration == null) return fallback.toString();
  return registration['teamName']?.toString() ??
      registration['clubName']?.toString() ??
      registration['name']?.toString() ??
      fallback.toString();
}

String _matchDateKey(dynamic value) {
  if (value is Timestamp) return value.toDate().toIso8601String();
  return value?.toString() ?? 'Fecha por definir';
}

String _matchDateLabel(String value) {
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value;
  return '${_weekdayName(parsed.weekday)} ${parsed.day} de ${_monthName(parsed.month)}';
}

String _matchTimeLabel(dynamic value) {
  final date = value is Timestamp ? value.toDate() : DateTime.tryParse(value?.toString() ?? '');
  if (date != null) return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  return 'Hora por definir';
}

String _weekdayName(int weekday) => const [
      '',
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo',
    ][weekday];

String _monthName(int month) => const [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre',
    ][month - 1];
