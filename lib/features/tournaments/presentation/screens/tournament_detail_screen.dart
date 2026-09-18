import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../domain/models/tournament_models.dart';
import '../../../../shared/widgets/app_bottom_navigation_bar.dart';
import 'team_registration_screen.dart';

/// Resumen responsive del torneo seleccionado.
/// El ListView permite que la información crezca sin desbordarse.
class TournamentDetailScreen extends StatelessWidget {
  const TournamentDetailScreen({required this.tournament, super.key});

  final Tournament tournament;

  @override
  Widget build(BuildContext context) {
    final status = tournament.status.toLowerCase();
    final isFinished = status == 'finished' || status == 'finalizado';
    final isPlaying = status == 'active' || status == 'playing' || status == 'jugando' || status == 'en_curso';
    final statusLabel = isFinished ? 'Finalizado' : isPlaying ? 'Jugando' : 'Por iniciar';
    final registrationClosed = tournament.registrationDeadline != null && DateTime.now().isAfter(tournament.registrationDeadline!);
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(tournament.name.isEmpty ? 'Detalle del torneo' : tournament.name)),
      bottomNavigationBar: AppBottomNavigationBar(selectedIndex: 0),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 24 + MediaQuery.paddingOf(context).bottom),
        children: [
          Text('Liga de Balonmano del Caquetá', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          Text(tournament.name, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _InfoBadge(label: statusLabel, color: isPlaying ? Colors.green : isFinished ? colors.onSurfaceVariant : Colors.amber),
            _InfoBadge(label: _formatLabel(tournament.format), color: colors.primary),
          ]),
          const SizedBox(height: 16),
          _StatsGrid(tournament: tournament),
          const SizedBox(height: 18),
          const _SectionTitle(title: 'Tabla de posiciones', action: 'Ver completa'),
          const SizedBox(height: 8),
          const _StandingRow(position: '1', team: 'La tabla se actualizará', points: '--'),
          const SizedBox(height: 18),
          const _SectionTitle(title: 'Destacados'),
          const SizedBox(height: 8),
          _Highlights(tournament: tournament),
          const SizedBox(height: 18),
          const _SectionTitle(title: 'Información del torneo'),
          const SizedBox(height: 8),
          _DetailsCard(tournament: tournament),
          const SizedBox(height: 18),
          if (tournament.publicRegistration)
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

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.tournament});
  final Tournament tournament;

  @override
  Widget build(BuildContext context) {
    final approvedTeams = FirebaseFirestore.instance
        .collection('tournaments')
        .doc(tournament.id)
        .collection('teams')
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
            _StatCard(label: 'Categorías', value: '${tournament.categories.length}'),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, this.onTap});
  final String label;
  final String value;
  final VoidCallback? onTap;

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

class _ApprovedTeamsScreen extends StatelessWidget {
  const _ApprovedTeamsScreen({required this.tournament});

  final Tournament tournament;

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collection('tournaments')
        .doc(tournament.id)
        .collection('registrations')
        .where('status', isEqualTo: 'approved')
        .snapshots();

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
                      builder: (_) => _ApprovedTeamDetailScreen(
                        tournament: tournament,
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

  Color _contrastColor(Color color) => color.computeLuminance() > 0.5 ? Colors.black : Colors.white;
}

class _ApprovedTeamDetailScreen extends StatelessWidget {
  const _ApprovedTeamDetailScreen({
    required this.tournament,
    required this.registration,
    required this.teamColor,
  });

  final Tournament tournament;
  final Map<String, dynamic> registration;
  final Color teamColor;

  @override
  Widget build(BuildContext context) {
    final teamName = registration['teamName']?.toString().trim().isNotEmpty == true
        ? registration['teamName'].toString()
        : 'Equipo sin nombre';
    final players = (registration['players'] as List?)?.whereType<Map>().toList() ?? const <Map>[];
    final coach = registration['coachName']?.toString() ?? 'Entrenador no registrado';
    final category = registration['category']?.toString() ?? 'Categoría no registrada';

    return Scaffold(
      appBar: AppBar(title: Text(teamName)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: teamColor,
                foregroundColor: _contrastColor(teamColor),
                child: Text(teamName.substring(0, 1).toUpperCase(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(teamName, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                    Text('$category · DT: $coach'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: _TeamMetric(label: 'Jugadores', value: '${players.length}')),
              const SizedBox(width: 8),
              Expanded(child: _TeamMetric(label: 'Posición', value: '--')),
              const SizedBox(width: 8),
              Expanded(child: _TeamMetric(label: 'Puntos', value: '--')),
            ],
          ),
          const SizedBox(height: 20),
          Text('Plantilla (${players.length})', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          if (players.isEmpty)
            const Card(child: ListTile(title: Text('No hay jugadores registrados.')))
          else
            ...players.asMap().entries.map((entry) => _PlayerRow(player: entry.value, index: entry.key)),
        ],
      ),
    );
  }

  Color _contrastColor(Color color) => color.computeLuminance() > 0.5 ? Colors.black : Colors.white;
}

class _TeamMetric extends StatelessWidget {
  const _TeamMetric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: Theme.of(context).textTheme.bodySmall), const SizedBox(height: 4), Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))]),
        ),
      );
}

class _PlayerRow extends StatelessWidget {
  const _PlayerRow({required this.player, required this.index});
  final Map player;
  final int index;

  @override
  Widget build(BuildContext context) {
    final name = player['name']?.toString() ?? 'Jugador';
    final position = player['position']?.toString() ?? 'Sin posición';
    final number = player['number']?.toString() ?? '--';
    final goals = player['goals']?.toString();
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        dense: true,
        leading: SizedBox(width: 28, child: Text(number == '--' ? '${index + 1}' : '#$number')),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(position),
        trailing: goals == null ? null : Text('$goals goles'),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.action});
  final String title;
  final String? action;

  @override
  Widget build(BuildContext context) => Row(children: [Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)), if (action != null) Text(action!, style: Theme.of(context).textTheme.bodySmall)]);
}

class _StandingRow extends StatelessWidget {
  const _StandingRow({required this.position, required this.team, required this.points});
  final String position;
  final String team;
  final String points;

  @override
  Widget build(BuildContext context) => Card(child: ListTile(dense: true, leading: Text(position), title: Text(team), trailing: Text(points, style: const TextStyle(fontWeight: FontWeight.bold))));
}

class _Highlights extends StatelessWidget {
  const _Highlights({required this.tournament});

  final Tournament tournament;

  bool get _isMixed => tournament.categories.any((category) => category.toLowerCase().contains('mixto'));

  @override
  Widget build(BuildContext context) => Column(
        children: [
          if (_isMixed)
            const _HighlightCard(
              icon: Icons.emoji_events_outlined,
              title: 'Máximo goleador masculino',
              subtitle: 'Tabla de goleadores masculino',
              value: '-- goles',
            )
          else
            const _HighlightCard(
              icon: Icons.emoji_events_outlined,
              title: 'Máximo goleador',
              subtitle: 'Los resultados aparecerán aquí',
              value: '-- goles',
            ),
          if (_isMixed)
            const _HighlightCard(
              icon: Icons.emoji_events_outlined,
              title: 'Máxima goleadora femenina',
              subtitle: 'Tabla de goleadoras femenino',
              value: '-- goles',
            ),
          const _HighlightCard(
            icon: Icons.shield_outlined,
            title: 'Valla menos vencida',
            subtitle: 'Tabla de porteros, sin importar el género',
            value: '-- goles',
          ),
        ],
      );
}

class _HighlightCard extends StatelessWidget {
  const _HighlightCard({required this.icon, required this.title, required this.subtitle, required this.value});
  final IconData icon;
  final String title;
  final String subtitle;
  final String value;

  @override
  Widget build(BuildContext context) => Card(child: ListTile(leading: Icon(icon), title: Text(title), subtitle: Text(subtitle), trailing: Text(value, style: const TextStyle(fontWeight: FontWeight.bold))));
}

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.tournament});
  final Tournament tournament;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Categorías y ramas', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: tournament.categories.map((category) => Chip(label: Text(category.replaceAll('|', ' · ')))).toList()),
            const SizedBox(height: 8),
            Text('Inscripción pública: ${tournament.publicRegistration ? 'Sí' : 'No'}'),
            Text('Fecha de inicio: ${tournament.startDate == null ? 'Pendiente' : _date(tournament.startDate!)}'),
            Text('Fecha de finalización: ${tournament.endDate == null ? 'No definida' : _date(tournament.endDate!)}'),
          ]),
        ),
      );

  String _date(DateTime value) => '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
}

class _InfoBadge extends StatelessWidget {
  const _InfoBadge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => DecoratedBox(decoration: BoxDecoration(color: color.withValues(alpha: .18), borderRadius: BorderRadius.circular(8)), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600))));
}

String _formatLabel(String value) => value == 'todos_contra_todos' ? 'Todos contra todos' : value == 'por_grupos' ? 'Por grupos' : value;
