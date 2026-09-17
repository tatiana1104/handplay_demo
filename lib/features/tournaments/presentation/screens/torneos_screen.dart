import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/app_bottom_navigation_bar.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../data/tournament_repository.dart';
import '../../domain/models/tournament_models.dart';
import 'tournament_detail_screen.dart';

/// Home público y panel de torneos de la liga de balonmano.
/// Solo el custom claim `rol: admin_liga` habilita la creación de torneos.
class TorneosScreen extends StatelessWidget {
  const TorneosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final user = authState is AuthAuthenticated ? authState.user : null;

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Liga de Balonmano del Caquetá', style: TextStyle(fontSize: 12)),
            Text('Mis torneos'),
          ],
        ),
        actions: [if (user != null) _CreateTournamentAction(userId: user.uid)],
      ),
      bottomNavigationBar: AppBottomNavigationBar(
        selectedIndex: 0,
        isAuthenticated: user != null,
      ),
      body: const _PublicTournamentList(),
    );
  }
}

class _CreateTournamentAction extends StatelessWidget {
  const _CreateTournamentAction({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<IdTokenResult>(
      future: FirebaseAuth.instance.currentUser?.getIdTokenResult(),
      builder: (context, snapshot) {
        final role = snapshot.data?.claims?['rol'];
        if (role != 'admin_liga' && role != 'admin') return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(right: 12),
          child: FilledButton.icon(
            onPressed: () => context.push('/torneos/nuevo', extra: userId),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Nuevo torneo'),
          ),
        );
      },
    );
  }
}

enum _TournamentFilter { all, upcoming, playing, finished }

class _PublicTournamentList extends StatefulWidget {
  const _PublicTournamentList();

  @override
  State<_PublicTournamentList> createState() => _PublicTournamentListState();
}

class _PublicTournamentListState extends State<_PublicTournamentList> {
  _TournamentFilter _filter = _TournamentFilter.all;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Tournament>>(
      stream: TournamentRepository().watchPublicTournaments(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const _MessageCard(
            icon: Icons.lock_outline_rounded,
            message: 'No se pudieron cargar tus torneos.',
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final allTournaments = [...?snapshot.data];
        final visibleTournaments = allTournaments
            .where((tournament) => _matchesFilter(tournament, _filter))
            .toList()
          ..sort(_compareTournaments);

        return Column(
          children: [
            _FilterBar(
              selected: _filter,
              onChanged: (filter) => setState(() => _filter = filter),
            ),
            Expanded(
              child: visibleTournaments.isEmpty
                  ? const _EmptyFilteredTournaments()
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                      itemCount: visibleTournaments.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) => _TournamentCard(
                        tournament: visibleTournaments[index],
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => TournamentDetailScreen(
                              tournament: visibleTournaments[index],
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  bool _matchesFilter(Tournament tournament, _TournamentFilter filter) {
    switch (filter) {
      case _TournamentFilter.all:
        return true;
      case _TournamentFilter.upcoming:
        return _statusOf(tournament) == _TournamentStatus.upcoming;
      case _TournamentFilter.playing:
        return _statusOf(tournament) == _TournamentStatus.playing;
      case _TournamentFilter.finished:
        return _statusOf(tournament) == _TournamentStatus.finished;
    }
  }

  int _compareTournaments(Tournament a, Tournament b) {
    final priority = {
      _TournamentStatus.upcoming: 0,
      _TournamentStatus.playing: 1,
      _TournamentStatus.finished: 2,
    };
    final statusComparison = priority[_statusOf(a)]!.compareTo(priority[_statusOf(b)]!);
    if (statusComparison != 0) return statusComparison;
    return (a.startDate ?? DateTime(9999)).compareTo(b.startDate ?? DateTime(9999));
  }
}

enum _TournamentStatus { upcoming, playing, finished }

_TournamentStatus _statusOf(Tournament tournament) {
  final status = tournament.status.trim().toLowerCase();
  if (status == 'finished' || status == 'finalizado' || status == 'completed') {
    return _TournamentStatus.finished;
  }
  if (status == 'active' || status == 'playing' || status == 'jugando' || status == 'en_curso') {
    return _TournamentStatus.playing;
  }
  return _TournamentStatus.upcoming;
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.selected, required this.onChanged});

  final _TournamentFilter selected;
  final ValueChanged<_TournamentFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Row(
        children: [
          _FilterChip(label: 'Todos', selected: selected == _TournamentFilter.all, onTap: () => onChanged(_TournamentFilter.all)),
          _FilterChip(label: 'Por iniciar', selected: selected == _TournamentFilter.upcoming, onTap: () => onChanged(_TournamentFilter.upcoming)),
          _FilterChip(label: 'Jugando', selected: selected == _TournamentFilter.playing, onTap: () => onChanged(_TournamentFilter.playing)),
          _FilterChip(label: 'Terminados', selected: selected == _TournamentFilter.finished, onTap: () => onChanged(_TournamentFilter.finished)),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: colors.primary.withValues(alpha: .22),
        checkmarkColor: colors.primary,
        side: BorderSide(color: selected ? colors.primary : colors.outlineVariant),
      ),
    );
  }
}

class _PublicHomeContent extends StatelessWidget {
  const _PublicHomeContent();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Icon(Icons.sports_handball_rounded, size: 72),
        const SizedBox(height: 20),
        Text('Gestiona tu liga de balonmano', style: textTheme.headlineMedium),
        const SizedBox(height: 12),
        Text('Consulta torneos, equipos, partidos y resultados desde un solo lugar.', style: textTheme.bodyLarge),
      ],
    );
  }
}

class _EmptyFilteredTournaments extends StatelessWidget {
  const _EmptyFilteredTournaments();

  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('No hay torneos en este estado.'),
        ),
      );
}

class _TournamentCard extends StatelessWidget {
  const _TournamentCard({required this.tournament, required this.onTap});

  final Tournament tournament;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = _statusOf(tournament);
    final isPlaying = status == _TournamentStatus.playing;
    final isFinished = status == _TournamentStatus.finished;
    final label = isFinished ? 'terminado' : isPlaying ? 'jugando' : 'por iniciar';
    final progress = isFinished ? 1.0 : isPlaying ? .45 : .05;
    final dateLabel = tournament.startDate == null
        ? 'Fecha de inicio pendiente'
        : '${isFinished ? 'Finalizó' : 'Inicia'}: ${tournament.startDate!.day.toString().padLeft(2, '0')}/${tournament.startDate!.month.toString().padLeft(2, '0')}/${tournament.startDate!.year}';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(isPlaying ? Icons.star_rounded : Icons.star_border_rounded, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(tournament.name.isEmpty ? 'Torneo sin nombre' : tournament.name, style: Theme.of(context).textTheme.titleMedium)),
              _StatusPill(label: label, status: status),
            ]),
            const SizedBox(height: 6),
            Text('${tournament.format} · ${tournament.teamLimit} equipos', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            LinearProgressIndicator(value: progress),
            const SizedBox(height: 8),
            Text(dateLabel, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.status});

  final String label;
  final _TournamentStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = status == _TournamentStatus.playing
        ? Colors.green
        : status == _TournamentStatus.finished
            ? colors.onSurfaceVariant
            : Colors.amber;
    return DecoratedBox(
      decoration: BoxDecoration(color: color.withValues(alpha: .18), borderRadius: BorderRadius.circular(6)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(label, style: TextStyle(fontSize: 11, color: color)),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 48), const SizedBox(height: 12), Text(message, textAlign: TextAlign.center)])));
}
