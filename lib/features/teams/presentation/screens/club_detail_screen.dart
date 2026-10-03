import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../shared/widgets/detail_summary_card.dart';
import '../../../../shared/widgets/metric_tile.dart';
import '../../domain/models/club_model.dart';

/// Muestra los equipos y las personas relacionadas con un club oficial.
class ClubDetailScreen extends StatelessWidget {
  const ClubDetailScreen({required this.club, super.key});

  final ClubModel club;

  static String _normalizeName(String? value) => value == null
      ? ''
      : value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  static bool _matchesClub(Map<String, dynamic> registration, String clubName) {
    final normalizedClubName = _normalizeName(clubName);
    final candidateNames = <String>{
      _normalizeName(registration['clubName']?.toString()),
      ...((registration['clubs'] as List?)
              ?.whereType<String>()
              .map(_normalizeName)
              .where((value) => value.isNotEmpty)
              .toList() ??
          const <String>[]),
    }.where((value) => value.isNotEmpty).toList();

    if (candidateNames.isEmpty) return false;
    return candidateNames.any(
      (candidate) =>
          candidate == normalizedClubName ||
          candidate.contains(normalizedClubName) ||
          normalizedClubName.contains(candidate),
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = FirebaseFirestore.instance.collectionGroup('registrations');

    return Scaffold(
      appBar: AppBar(title: Text(club.name)),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: query.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('No se pudo cargar la información del club.'),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final teams = snapshot.data!.docs
              .map((doc) => doc.data())
              .where((registration) => _matchesClub(registration, club.name))
              .toList();

          final players = <Map<String, dynamic>>[];
          for (final team in teams) {
            final teamPlayers = (team['players'] as List?)
                    ?.whereType<Map>()
                    .map((player) => Map<String, dynamic>.from(player))
                    .toList() ??
                const <Map<String, dynamic>>[];
            players.addAll(teamPlayers);
          }

          if (teams.isEmpty) {
            return const Center(
              child: Text('Este club todavía no tiene equipos inscritos.'),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              DetailSummaryCard(
                title: club.name,
                subtitle: '${teams.length} equipos · ${players.length} jugadores',
                leading: const CircleAvatar(
                  radius: 20,
                  child: Icon(Icons.groups_2_outlined, size: 20),
                ),
              ),
              const SizedBox(height: 16),
              const SectionHeader('Listado de jugadores'),
              const SizedBox(height: 8),
              if (players.isEmpty)
                const EmptySection(
                  icon: Icons.person_off_outlined,
                  message: 'Este club todavía no tiene jugadores registrados.',
                )
              else
                ...players.map(
                  (player) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _PlayerListTile(
                      teamName: (player['teamName'] ?? '').toString(),
                      name: player['name']?.toString() ?? 'Jugador sin nombre',
                      number: player['number']?.toString(),
                      position: player['position']?.toString(),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              const SectionHeader('Equipos'),
              const SizedBox(height: 8),
              ...teams.map(
                (registration) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _TeamCard(registration: registration),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TeamCard extends StatelessWidget {
  const _TeamCard({required this.registration});

  final Map<String, dynamic> registration;

  @override
  Widget build(BuildContext context) {
    final teamName = registration['teamName']?.toString().trim();
    final coach = registration['coachName']?.toString().trim();
    final players = (registration['players'] as List?)
            ?.whereType<Map>()
            .map((player) => Map<String, dynamic>.from(player))
            .toList() ??
        const <Map<String, dynamic>>[];

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        leading: const CircleAvatar(
          radius: 16,
          child: Icon(Icons.shield_outlined, size: 18),
        ),
        title: Text(
          teamName?.isNotEmpty == true ? teamName! : 'Equipo sin nombre',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${players.length} jugadores',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        children: [
          if (coach?.isNotEmpty == true)
            _PersonTile(
              icon: Icons.sports_outlined,
              label: 'Entrenador',
              name: coach!,
              detail: registration['coachEmail']?.toString(),
            ),
          for (final player in players)
            _PersonTile(
              icon: Icons.person_outline,
              label: 'Jugador${player['number'] == null ? '' : ' #${player['number']}'}',
              name: player['name']?.toString() ?? 'Jugador sin nombre',
              detail: player['position']?.toString(),
            ),
        ],
      ),
    );
  }
}

class _PlayerListTile extends StatelessWidget {
  const _PlayerListTile({
    required this.teamName,
    required this.name,
    this.number,
    this.position,
  });

  final String teamName;
  final String name;
  final String? number;
  final String? position;

  @override
  Widget build(BuildContext context) {
    final subtitle = <String>[];
    if (position?.trim().isNotEmpty == true) subtitle.add(position!);
    if (number?.trim().isNotEmpty == true) subtitle.add('Camiseta #$number');
    if (teamName.trim().isNotEmpty) subtitle.add(teamName);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.35),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        dense: true,
        leading: const CircleAvatar(
          radius: 16,
          child: Icon(Icons.person_outline, size: 18),
        ),
        title: Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: subtitle.isEmpty
            ? null
            : Text(
                subtitle.join(' · '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
      ),
    );
  }
}

class _PersonTile extends StatelessWidget {
  const _PersonTile({required this.icon, required this.label, required this.name, this.detail});

  final IconData icon;
  final String label;
  final String name;
  final String? detail;

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon),
        title: Text(name),
        subtitle: Text([label, if (detail?.trim().isNotEmpty == true) detail!].join(' · ')),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(name),
            content: Text([label, if (detail?.trim().isNotEmpty == true) detail!].join('\n')),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cerrar'),
              ),
            ],
          ),
        ),
      );
}
