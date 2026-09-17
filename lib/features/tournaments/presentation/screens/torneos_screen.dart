import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/widgets/app_bottom_navigation_bar.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../data/tournament_repository.dart';
import '../../domain/models/tournament_models.dart';

/// Home público de HandPlay.
///
/// Los visitantes ven la propuesta de valor sin autenticarse. Cuando existe
/// una sesión, la misma pantalla cambia a la lista de torneos del usuario.
class TorneosScreen extends StatelessWidget {
  const TorneosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final user = authState is AuthAuthenticated ? authState.user : null;

    return Scaffold(
      appBar: AppBar(title: const Text('HandPlay')),
      bottomNavigationBar: user == null
          ? null
          : const AppBottomNavigationBar(selectedIndex: 0),
      body: user == null
          ? const _PublicHomeContent()
          : StreamBuilder<List<Tournament>>(
              stream: TournamentRepository()
                  .watchTournamentsForAdmin(user.uid),
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

                final tournaments = snapshot.data ?? const <Tournament>[];
                if (tournaments.isEmpty) {
                  return const _MessageCard(
                    icon: Icons.emoji_events_outlined,
                    message: 'Aún no tienes torneos registrados.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: tournaments.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) => _TournamentCard(
                    tournament: tournaments[index],
                  ),
                );
              },
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
        Text('Gestiona tu liga de pádel', style: textTheme.headlineMedium),
        const SizedBox(height: 12),
        Text(
          'Consulta torneos, equipos, partidos y resultados desde un solo lugar.',
          style: textTheme.bodyLarge,
        ),
      ],
    );
  }
}

class _TournamentCard extends StatelessWidget {
  const _TournamentCard({required this.tournament});

  final Tournament tournament;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.emoji_events_outlined)),
        title: Text(tournament.name.isEmpty ? 'Torneo sin nombre' : tournament.name),
        subtitle: Text('${tournament.status} · ${tournament.format}'),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
