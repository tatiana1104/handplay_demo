import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../shared/widgets/info_value_row.dart';
import '../../../../shared/widgets/metric_tile.dart';
import '../../../tournaments/domain/models/tournament_models.dart';
import '../../domain/team_stats_calculator.dart';
import 'team_detail_screen.dart';

/// Ficha del jugador con estadísticas reales calculadas a partir de los
/// eventos registrados por el planillero en los partidos finalizados.
/// EN: Player profile with statistics calculated from recorded events in completed matches.
class PlayerProfileScreen extends StatelessWidget {
  /// ES: Crea la ficha del jugador dentro de un torneo y equipo.
  /// EN: Creates the player's profile within a tournament and team.
  const PlayerProfileScreen({
    required this.tournament,
    required this.player,
    required this.teamName,
    required this.teamColor,
    required this.teamIdentifiers,
    super.key,
  });

  final Tournament tournament;
  final Map player;
  final String teamName;
  final Color teamColor;
  final Set<String> teamIdentifiers;

  /// ES: Calcula y muestra estadísticas e historial en tiempo real.
  /// EN: Calculates and displays live statistics and match history.
  @override
  Widget build(BuildContext context) {
    final name = capitalize((player['name'] ?? player['nombre'] ?? 'Jugador').toString());
    final number = player['number']?.toString().trim();
    final position = player['position']?.toString().trim();
    final gender = (player['gender'] ?? player['genero'])?.toString().trim();
    final document = player['document']?.toString().trim();
    final isReferee = player['isReferee'] == true || player['arbitro'] == true;

    return Scaffold(
      appBar: AppBar(title: const Text('Ficha del jugador')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('tournaments').doc(tournament.id).collection('matches').snapshots(),
        builder: (context, snapshot) {
          final loading = !snapshot.hasData && !snapshot.hasError;
          final matches = teamMatches(identifiers: teamIdentifiers, matches: snapshot.data?.docs ?? const []);
          final stats = playerStats(player: player, teamMatches: matches);
          String show(Object value) => loading ? '…' : '$value';

          return ListView(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 24 + MediaQuery.paddingOf(context).bottom),
            children: [
              ProfileHeader(
                title: name,
                color: teamColor,
                badge: number == null || number.isEmpty ? null : number,
                subtitle: teamName,
                chips: [
                  if (position != null && position.isNotEmpty) position,
                  if (number != null && number.isNotEmpty) 'Dorsal $number',
                  if (gender != null && gender.isNotEmpty) capitalize(gender),
                ],
              ),
              const SectionHeader('Estadísticas del torneo'),
              MetricGrid(children: [
                MetricTile(label: 'Goles', value: show(stats.goals), icon: Icons.sports_handball),
                MetricTile(label: 'Partidos', value: show(stats.matchesPlayed), icon: Icons.event_available_outlined),
                MetricTile(label: 'Promedio', value: show(stats.average), icon: Icons.trending_up),
                MetricTile(label: 'Amarillas', value: show(stats.yellowCards), accent: Colors.amber),
                MetricTile(label: 'Rojas', value: show(stats.redCards), accent: Theme.of(context).colorScheme.error),
                MetricTile(label: 'Exclusiones', value: show(stats.exclusions), icon: Icons.timer_outlined),
              ]),
              const SectionHeader('Datos personales'),
              Card(
                margin: EdgeInsets.zero,
                child: Column(children: [
                  InfoValueRow(label: 'Equipo', value: teamName),
                  InfoValueRow(label: 'Posición', value: position?.isNotEmpty == true ? position! : 'Sin posición'),
                  InfoValueRow(label: 'Dorsal', value: number?.isNotEmpty == true ? '#$number' : 'Sin número'),
                  if (gender != null && gender.isNotEmpty) InfoValueRow(label: 'Rama', value: capitalize(gender)),
                  if (document != null && document.isNotEmpty) InfoValueRow(label: 'Documento', value: _maskDocument(document)),
                ]),
              ),
              if (isReferee) ...[
                const SizedBox(height: 12),
                Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    leading: const Icon(Icons.sports, color: Colors.amber),
                    title: const Text('También está habilitado como árbitro'),
                  ),
                ),
              ],
              SectionHeader('Historial de partidos', trailing: stats.history.isEmpty ? null : '${stats.history.length} jugados'),
              if (loading)
                const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
              else if (stats.history.isEmpty)
                const EmptySection(icon: Icons.history, message: 'Aún no ha disputado partidos finalizados en este torneo.')
              else
                for (final line in stats.history) MatchResultTile(match: line.match, trailingDetail: _lineDetail(line)),
            ],
          );
        },
      ),
    );
  }

  /// ES: Resume goles y sanciones del jugador para una línea del historial.
  /// EN: Summarizes a player's goals and sanctions for one history row.
  String? _lineDetail(PlayerMatchLine line) {
    final parts = [
      if (line.goals > 0) '${line.goals} ${line.goals == 1 ? 'gol' : 'goles'}',
      if (line.yellowCards > 0) '${line.yellowCards} TA',
      if (line.redCards > 0) '${line.redCards} TR',
      if (line.exclusions > 0) '${line.exclusions} excl.',
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  /// ES: Oculta el documento y deja visibles solo sus últimos cuatro caracteres.
  /// EN: Masks the identity document while keeping its last four characters visible.
  String _maskDocument(String value) => value.length <= 4 ? value : '${'•' * (value.length - 4)}${value.substring(value.length - 4)}';
}

