import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../domain/models/club_model.dart';

/// Muestra los equipos y las personas relacionadas con un club oficial.
class ClubDetailScreen extends StatelessWidget {
  const ClubDetailScreen({required this.club, super.key});

  final ClubModel club;

  @override
  Widget build(BuildContext context) {
    final query = FirebaseFirestore.instance
        .collectionGroup('registrations')
        .where('clubs', arrayContains: club.name);

    return Scaffold(
      appBar: AppBar(title: Text(club.name)),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: query.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('No se pudo cargar la información del club.'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final teams = snapshot.data!.docs;
          if (teams.isEmpty) {
            return const Center(child: Text('Este club todavía no tiene equipos inscritos.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            itemCount: teams.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) => _TeamCard(registration: teams[index].data()),
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
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: const CircleAvatar(child: Icon(Icons.shield_outlined)),
        title: Text(teamName?.isNotEmpty == true ? teamName! : 'Equipo sin nombre'),
        subtitle: Text('${players.length} jugadores'),
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
