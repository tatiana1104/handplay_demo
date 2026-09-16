import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/route_names.dart';
import '../../data/tournament_repository.dart';

/// Pantalla principal de Sprint 2: filtra torneos activos/finalizados y deja
/// que el usuario abra el detalle o marque un torneo como favorito.
/// Lista reactiva de torneos asociados al usuario autenticado.
/// La consulta vive en el repositorio; esta pantalla solo transforma estados
/// en UI y delega las escrituras para mantener la separación de responsabilidades.
class TorneosScreen extends StatefulWidget {
  const TorneosScreen({super.key});

  @override
  State<TorneosScreen> createState() => _TorneosScreenState();
}

class _TorneosScreenState extends State<TorneosScreen> {
  final _repository = TournamentRepository();
  bool _showFinished = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis torneos')),
      body: StreamBuilder<List<Tournament>>(
        stream: _repository.watchMyTournaments(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text(firestoreErrorMessage(snapshot.error!)));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final tournaments = snapshot.data!.where((tournament) => _showFinished ? tournament.status == 'finished' : tournament.status != 'finished').toList();
          return RefreshIndicator(
            onRefresh: () async => setState(() {}),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                SegmentedButton<bool>(segments: const [ButtonSegment(value: false, label: Text('Activos')), ButtonSegment(value: true, label: Text('Finalizados'))], selected: {_showFinished}, onSelectionChanged: (selection) => setState(() => _showFinished = selection.first)),
                const SizedBox(height: 18),
                if (tournaments.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(24), child: Center(child: Text('No hay torneos en esta sección.')))),
                ...tournaments.map(_TournamentCard.new),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _TournamentCard(Tournament tournament) => Card(
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: CircleAvatar(child: Icon(tournament.status == 'finished' ? Icons.emoji_events : Icons.sports_tennis)),
          title: Text(tournament.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text('Jornada ${tournament.currentRound}/${tournament.totalRounds}\n${tournament.nextMatch}'),
          isThreeLine: true,
          trailing: IconButton(icon: Icon(tournament.isFavorite ? Icons.star : Icons.star_border), tooltip: tournament.isFavorite ? 'Quitar favorito' : 'Marcar favorito', onPressed: () => _repository.toggleFavorite(tournament)),
          onTap: () => context.push('${RouteNames.tournament}/${tournament.id}', extra: tournament),
        ),
      );
}

EOF
