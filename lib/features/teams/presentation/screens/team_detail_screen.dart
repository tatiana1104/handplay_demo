import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../shared/widgets/metric_tile.dart';
import '../../../tournaments/domain/models/tournament_models.dart';
import '../../../tournaments/presentation/utils/standings_calculator.dart';
import '../../domain/team_stats_calculator.dart';
import 'player_profile_screen.dart';

/// Ficha de un equipo inscrito: posición y puntos reales en la tabla,
/// rendimiento, cuerpo técnico, plantilla con goles y últimos partidos.
class TeamDetailScreen extends StatelessWidget {
  const TeamDetailScreen({
    required this.tournament,
    required this.registrationId,
    required this.registration,
    required this.teamColor,
    super.key,
  });

  final Tournament tournament;
  final String registrationId;
  final Map<String, dynamic> registration;
  final Color teamColor;

  String get teamName {
    final name = registration['teamName']?.toString().trim() ?? '';
    return name.isEmpty ? 'Equipo sin nombre' : name;
  }

  @override
  Widget build(BuildContext context) {
    final tournamentRef = FirebaseFirestore.instance.collection('tournaments').doc(tournament.id);
    return Scaffold(
      appBar: AppBar(title: Text(teamName, overflow: TextOverflow.ellipsis)),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: tournamentRef.collection('registrations').snapshots(),
        builder: (context, registrations) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: tournamentRef.collection('matches').snapshots(),
          builder: (context, matches) {
            final registrationDocs = registrations.data?.docs ?? const [];
            final matchDocs = matches.data?.docs ?? const [];
            final standings = calculateStandings(registrations: registrationDocs, matches: matchDocs);
            final index = standings.indexWhere((row) => normalizeKey(row.team) == normalizeKey(teamName));
            final standing = index < 0 ? null : standings[index];
            final summaries = teamMatches(identifiers: registrationIdentifiers(registrationId, registration), matches: matchDocs);
            return _TeamDetailBody(
              screen: this,
              position: index < 0 ? null : index + 1,
              totalTeams: standings.length,
              standing: standing,
              matches: summaries,
              loading: !registrations.hasData || !matches.hasData,
            );
          },
        ),
      ),
    );
  }
}

class _TeamDetailBody extends StatelessWidget {
  const _TeamDetailBody({
    required this.screen,
    required this.position,
    required this.totalTeams,
    required this.standing,
    required this.matches,
    required this.loading,
  });

  final TeamDetailScreen screen;
  final int? position;
  final int totalTeams;
  final StandingEntry? standing;
  final List<TeamMatchSummary> matches;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final registration = screen.registration;
    final players = (registration['players'] as List?)?.whereType<Map>().toList() ?? const <Map>[];
    final sortedPlayers = [...players]..sort((a, b) => (int.tryParse('${a['number']}') ?? 999).compareTo(int.tryParse('${b['number']}') ?? 999));
    final coach = registration['coachName']?.toString().trim();
    final assistant = (registration['assistantName'] ?? registration['assistantCoach'])?.toString().trim();
    final uniform = (registration['uniformColor'] ?? registration['jerseyColor'])?.toString().trim();
    final finished = matches.where((m) => m.finished).toList();
    final upcoming = matches.where((m) => !m.finished).toList().reversed.toList();
    final form = finished.take(5).map((m) => m.outcome).toList();
    final value = loading ? '…' : null;

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 24 + MediaQuery.paddingOf(context).bottom),
      children: [
        ProfileHeader(
          title: screen.teamName,
          color: screen.teamColor,
          subtitle: coach == null || coach.isEmpty ? 'Entrenador no registrado' : 'DT: $coach',
          chips: [formatCategory(registration['category']), if (uniform != null && uniform.isNotEmpty) 'Uniforme ${uniform.toLowerCase()}'],
        ),
        const SectionHeader('Rendimiento'),
        MetricGrid(children: [
          MetricTile(label: 'Posición', value: value ?? (position == null ? '--' : '$position° / $totalTeams'), icon: Icons.leaderboard_outlined),
          MetricTile(label: 'Puntos', value: value ?? '${standing?.points ?? 0}', icon: Icons.star_outline),
          MetricTile(label: 'Jugados', value: value ?? '${standing?.played ?? 0}', icon: Icons.sports_handball),
          MetricTile(label: 'G · E · P', value: value ?? '${standing?.wins ?? 0}-${standing?.draws ?? 0}-${standing?.losses ?? 0}'),
          MetricTile(label: 'Goles a favor', value: value ?? '${standing?.goalsFor ?? 0}'),
          MetricTile(label: 'Goles en contra', value: value ?? '${standing?.goalsAgainst ?? 0}'),
          MetricTile(label: 'Diferencia', value: value ?? _signed(standing?.goalDifference ?? 0)),
          MetricTile(label: 'Jugadores', value: '${players.length}', icon: Icons.groups_outlined),
        ]),
        if (form.isNotEmpty) ...[
          const SectionHeader('Racha reciente'),
          Row(children: [for (final outcome in form) Padding(padding: const EdgeInsets.only(right: 6), child: _OutcomeBadge(outcome))]),
        ],
        const SectionHeader('Cuerpo técnico'),
        Card(
          margin: EdgeInsets.zero,
          child: Column(children: [
            _InfoRow(icon: Icons.sports, label: 'Director técnico', value: coach?.isNotEmpty == true ? coach! : 'No registrado'),
            if (assistant != null && assistant.isNotEmpty) _InfoRow(icon: Icons.person_outline, label: 'Asistente', value: assistant),
            if (registration['coachPhone'] != null) _InfoRow(icon: Icons.phone_outlined, label: 'Teléfono', value: registration['coachPhone'].toString()),
            if (registration['coachEmail'] != null) _InfoRow(icon: Icons.mail_outline, label: 'Correo', value: registration['coachEmail'].toString()),
          ]),
        ),
        SectionHeader('Plantilla', trailing: '${players.length} jugadores'),
        if (players.isEmpty)
          const EmptySection(icon: Icons.person_off_outlined, message: 'No hay jugadores registrados.')
        else
          Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: Column(children: [
              for (var i = 0; i < sortedPlayers.length; i++) ...[
                if (i > 0) const Divider(height: 1, indent: 64),
                _PlayerTile(
                  player: sortedPlayers[i],
                  goals: playerStats(player: sortedPlayers[i], teamMatches: matches).goals,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => PlayerProfileScreen(
                      tournament: screen.tournament,
                      player: sortedPlayers[i],
                      teamName: screen.teamName,
                      teamColor: screen.teamColor,
                      teamIdentifiers: registrationIdentifiers(screen.registrationId, registration),
                    ),
                  )),
                ),
              ],
            ]),
          ),
        if (upcoming.isNotEmpty) ...[
          const SectionHeader('Próximos partidos'),
          for (final match in upcoming.take(3)) MatchResultTile(match: match),
        ],
        SectionHeader('Resultados', trailing: finished.isEmpty ? null : '${finished.length} partidos'),
        if (finished.isEmpty)
          const EmptySection(icon: Icons.event_busy_outlined, message: 'Todavía no hay partidos finalizados.')
        else
          for (final match in finished) MatchResultTile(match: match),
      ],
    );
  }

  String _signed(int value) => value > 0 ? '+$value' : '$value';
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 12),
        Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(width: 12),
        Expanded(child: Text(value, textAlign: TextAlign.end, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600))),
      ]),
    );
  }
}

class _PlayerTile extends StatelessWidget {
  const _PlayerTile({required this.player, required this.goals, required this.onTap});
  final Map player;
  final int goals;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final name = (player['name'] ?? player['nombre'] ?? 'Jugador').toString();
    final number = player['number']?.toString().trim();
    final position = player['position']?.toString().trim();
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: colors.primary.withValues(alpha: .15), borderRadius: BorderRadius.circular(10)),
            child: Text(number == null || number.isEmpty ? '--' : number, style: theme.textTheme.titleSmall?.copyWith(color: colors.primary, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(capitalize(name), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(position == null || position.isEmpty ? 'Sin posición' : position, style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
            ]),
          ),
          if (goals > 0)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Text('$goals ${goals == 1 ? 'gol' : 'goles'}', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
            ),
          Icon(Icons.chevron_right, color: colors.onSurfaceVariant),
        ]),
      ),
    );
  }
}

class _OutcomeBadge extends StatelessWidget {
  const _OutcomeBadge(this.outcome);
  final MatchOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final (label, color) = outcomeStyle(context, outcome);
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color.withValues(alpha: .18), borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w800)),
    );
  }
}

(String, Color) outcomeStyle(BuildContext context, MatchOutcome outcome) => switch (outcome) {
      MatchOutcome.win => ('G', Theme.of(context).colorScheme.primary),
      MatchOutcome.draw => ('E', Colors.amber),
      MatchOutcome.loss => ('P', Theme.of(context).colorScheme.error),
      MatchOutcome.pending => ('-', Theme.of(context).colorScheme.onSurfaceVariant),
    };

String formatShortDate(DateTime? date) {
  if (date == null) return 'Fecha por definir';
  const months = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
  final time = '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  return '${date.day} ${months[date.month - 1]} · $time';
}

/// Fila de un partido del equipo: rival, fecha, local/visitante y marcador.
class MatchResultTile extends StatelessWidget {
  const MatchResultTile({required this.match, this.trailingDetail, super.key});
  final TeamMatchSummary match;
  final String? trailingDetail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final (label, color) = outcomeStyle(context, match.outcome);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: color.withValues(alpha: .18), borderRadius: BorderRadius.circular(8)),
            child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('vs ${match.opponent}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(
                '${match.isHome ? 'Local' : 'Visitante'} · ${formatShortDate(match.date)}${trailingDetail == null ? '' : ' · $trailingDetail'}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              ),
            ]),
          ),
          const SizedBox(width: 8),
          Text(
            match.finished ? '${match.goalsFor} - ${match.goalsAgainst}' : 'vs',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ]),
      ),
    );
  }
}
