import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/app_bottom_navigation_bar.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../data/tournament_repository.dart';
import '../../domain/models/tournament_models.dart';

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
      bottomNavigationBar: AppBottomNavigationBar(selectedIndex: 0, isAuthenticated: user != null),
      body: user == null ? const _PublicHomeContent() : _AuthenticatedTournaments(userId: user.uid),
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

class _AuthenticatedTournaments extends StatelessWidget {
  const _AuthenticatedTournaments({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Tournament>>(
      stream: TournamentRepository().watchTournamentsForAdmin(userId),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const _MessageCard(icon: Icons.lock_outline_rounded, message: 'No se pudieron cargar tus torneos.');
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final tournaments = snapshot.data ?? const <Tournament>[];
        if (tournaments.isEmpty) return const _EmptyTournaments();
        return ListView.separated(padding: const EdgeInsets.fromLTRB(12, 12, 12, 24), itemCount: tournaments.length, separatorBuilder: (_, __) => const SizedBox(height: 10), itemBuilder: (context, index) => _TournamentCard(tournament: tournaments[index]));
      },
    );
  }
}

class _PublicHomeContent extends StatelessWidget {
  const _PublicHomeContent();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ListView(padding: const EdgeInsets.all(24), children: [const Icon(Icons.sports_handball_rounded, size: 72), const SizedBox(height: 20), Text('Gestiona tu liga de balonmano', style: textTheme.headlineMedium), const SizedBox(height: 12), Text('Consulta torneos, equipos, partidos y resultados desde un solo lugar.', style: textTheme.bodyLarge)]);
  }
}

class _EmptyTournaments extends StatelessWidget {
  const _EmptyTournaments();

  @override
  Widget build(BuildContext context) => const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('Aún no tienes torneos registrados.')));
}

class _TournamentCard extends StatelessWidget {
  const _TournamentCard({required this.tournament});

  final Tournament tournament;

  @override
  Widget build(BuildContext context) {
    final isActive = tournament.status == 'active';
    final progress = isActive ? .45 : .05;
    final dateLabel = tournament.startDate == null
        ? 'Fecha de inicio pendiente'
        : 'Inicia: ${tournament.startDate!.day.toString().padLeft(2, '0')}/${tournament.startDate!.month.toString().padLeft(2, '0')}/${tournament.startDate!.year}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(isActive ? Icons.star_rounded : Icons.star_border_rounded, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(tournament.name.isEmpty ? 'Torneo sin nombre' : tournament.name, style: Theme.of(context).textTheme.titleMedium)),
              _StatusPill(label: isActive ? 'en curso' : 'por iniciar', active: isActive),
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
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) => DecoratedBox(decoration: BoxDecoration(color: active ? Colors.green.withValues(alpha: .18) : Colors.amber.withValues(alpha: .18), borderRadius: BorderRadius.circular(6)), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), child: Text(label, style: TextStyle(fontSize: 11, color: active ? Colors.green : Colors.amber))));
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 48), const SizedBox(height: 12), Text(message, textAlign: TextAlign.center)])));
}
