import 'package:flutter/material.dart';

import '../../data/tournament_repository.dart';

/// Detalle del torneo y punto de entrada para administrar sus equipos.
/// La subcolección de equipos se escucha en tiempo real para que todos los
/// participantes vean los cambios sin refrescar manualmente.
class TournamentDetailScreen extends StatelessWidget {
  const TournamentDetailScreen({super.key, required this.tournament});

  final Tournament tournament;

  @override
  Widget build(BuildContext context) {
    final repository = TournamentRepository();
    return Scaffold(
      appBar: AppBar(title: Text(tournament.name)),
      body: StreamBuilder<List<Team>>(
        stream: repository.watchTeams(tournament.id),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text(firestoreErrorMessage(snapshot.error!)));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final teams = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Jornada ${tournament.currentRound}/${tournament.totalRounds}', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text(tournament.nextMatch),
                    const SizedBox(height: 14),
                    LinearProgressIndicator(value: tournament.totalRounds == 0 ? 0 : tournament.currentRound / tournament.totalRounds),
                  ]),
                ),
              ),
              const SizedBox(height: 24),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Equipos', style: Theme.of(context).textTheme.titleLarge),
                FilledButton.icon(onPressed: () => _showAddTeam(context, repository), icon: const Icon(Icons.add), label: const Text('Agregar')),
              ]),
              const SizedBox(height: 8),
              if (teams.isEmpty)
                const Card(child: Padding(padding: EdgeInsets.all(18), child: Text('Aún no hay equipos registrados.')))
              else
                ...teams.map((team) => Card(child: ListTile(leading: const CircleAvatar(child: Icon(Icons.groups)), title: Text(team.name), subtitle: Text('${team.members.length} jugadores')))),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showAddTeam(BuildContext context, TournamentRepository repository) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(context: context, builder: (context) => AlertDialog(
      title: const Text('Nuevo equipo'),
      content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(labelText: 'Nombre del equipo')),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Guardar'))],
    ));
    if (name != null && name.trim().isNotEmpty) await repository.addTeam(tournamentId: tournament.id, name: name);
  }
}
