import 'package:flutter/material.dart';

import '../../domain/models/tournament_models.dart';
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
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(tournament.name.isEmpty ? 'Detalle del torneo' : tournament.name)),
      bottomNavigationBar: const AppBottomNavigationBar(selectedIndex: 0),
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
          const _StandingRow(position: '1', team: 'Equipos registrados', points: '--'),
          const _StandingRow(position: '2', team: 'La tabla se actualizará', points: '--'),
          const SizedBox(height: 18),
          const _SectionTitle(title: 'Destacados'),
          const SizedBox(height: 8),
          const _HighlightCard(icon: Icons.emoji_events_outlined, title: 'Máximo goleador', subtitle: 'Los resultados aparecerán aquí', value: '-- goles'),
          const _HighlightCard(icon: Icons.shield_outlined, title: 'Valla menos vencida', subtitle: 'Se calcula al iniciar los partidos', value: '-- goles'),
          const SizedBox(height: 18),
          const _SectionTitle(title: 'Información del torneo'),
          const SizedBox(height: 8),
          _DetailsCard(tournament: tournament),
          const SizedBox(height: 18),
          if (tournament.publicRegistration)
            FilledButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => TeamRegistrationScreen(tournament: tournament)),
              ),
              icon: const Icon(Icons.group_add_rounded),
              label: const Text('Inscribir mi equipo'),
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
  Widget build(BuildContext context) => GridView.count(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 2.45,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _StatCard(label: 'Equipos', value: '${tournament.teamLimit}'),
          _StatCard(label: 'Categorías', value: '${tournament.categories.length}'),
        ],
      );
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: Text(label, style: Theme.of(context).textTheme.bodySmall)),
              const SizedBox(width: 8),
              Text(value, style: Theme.of(context).textTheme.titleLarge),
            ],
          ),
        ),
      );
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
