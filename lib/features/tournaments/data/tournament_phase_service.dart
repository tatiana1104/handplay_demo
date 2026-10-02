import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/models/tournament_models.dart';

/// Assigns approved teams and creates first-phase round-robin fixtures.
class TournamentPhaseService {
  TournamentPhaseService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<void> assignPhaseOne(Tournament tournament) async {
    final registrations = _firestore
        .collection('tournaments')
        .doc(tournament.id)
        .collection('registrations');
    final snapshot = await registrations.where('status', isEqualTo: 'approved').get();
    final teams = snapshot.docs.toList()..shuffle(Random.secure());
    if (teams.length < 2) return;

    final groupCount = tournament.format == 'por_grupos'
        ? max(2, min(tournament.groupCount, teams.length))
        : 1;
    final groups = List.generate(groupCount, (_) => <DocumentSnapshot<Map<String, dynamic>>>[]);
    for (var index = 0; index < teams.length; index++) {
      groups[index % groupCount].add(teams[index]);
    }

    final batch = _firestore.batch();
    for (var groupIndex = 0; groupIndex < groups.length; groupIndex++) {
      final groupName = tournament.format == 'por_grupos' ? _groupName(groupIndex) : 'General';
      for (final team in groups[groupIndex]) {
        batch.set(team.reference, {
          'phaseOneGroup': groupName,
          'phaseOnePosition': null,
          'phaseOneAssignedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    }
    await batch.commit();

    final matches = _firestore
        .collection('tournaments')
        .doc(tournament.id)
        .collection('matches');
    final existing = await matches.where('phase', isEqualTo: 1).get();
    final matchBatch = _firestore.batch();
    for (final document in existing.docs) {
      matchBatch.delete(document.reference);
    }
    for (var groupIndex = 0; groupIndex < groups.length; groupIndex++) {
      final group = groups[groupIndex];
      final groupName = tournament.format == 'por_grupos' ? _groupName(groupIndex) : 'General';
      var round = 1;
      for (var homeIndex = 0; homeIndex < group.length - 1; homeIndex++) {
        for (var awayIndex = homeIndex + 1; awayIndex < group.length; awayIndex++) {
          final match = matches.doc();
          matchBatch.set(match, {
            'id': match.id,
            'phase': 1,
            'jornada': round,
            'round': round,
            'group': groupName,
            'homeTeamId': group[homeIndex].id,
            'homeTeamName': group[homeIndex].data()?['teamName'] ?? '',
            'awayTeamId': group[awayIndex].id,
            'awayTeamName': group[awayIndex].data()?['teamName'] ?? '',
            'status': 'scheduled',
            'createdAt': FieldValue.serverTimestamp(),
          });
          round = round == group.length - 2 ? 1 : round + 1;
        }
      }
    }
    await matchBatch.commit();
  }

  String _groupName(int index) => String.fromCharCode('A'.codeUnitAt(0) + index);
}

List<int> advancingPositions(Tournament tournament) => tournament.advancingPositions;
                    
