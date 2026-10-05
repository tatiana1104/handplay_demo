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
      final fixtures = _roundRobinFixtures(group);
      for (final fixture in fixtures) {
        final home = group[fixture.$1];
        final away = group[fixture.$2];
        final match = matches.doc();
        matchBatch.set(match, {
          'id': match.id,
          'phase': 1,
          'jornada': fixture.$3,
          'round': fixture.$3,
          'leg': fixture.$4,
          'group': groupName,
          'homeTeamId': home.id,
          'homeTeamName': home.data()?['teamName'] ?? '',
          'awayTeamId': away.id,
          'awayTeamName': away.data()?['teamName'] ?? '',
          'status': 'scheduled',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    }
    await matchBatch.commit();
  }

  List<(int, int, int, String)> _roundRobinFixtures(
    List<DocumentSnapshot<Map<String, dynamic>>> group,
  ) {
    final firstLeg = <(int, int)>[];
    if (group.length == 3) {
      // Mantiene el orden solicitado: A-B, B-C, C-A.
      firstLeg.addAll(const [(0, 1), (1, 2), (2, 0)]);
    } else {
      for (var home = 0; home < group.length - 1; home++) {
        for (var away = home + 1; away < group.length; away++) {
          firstLeg.add((home, away));
        }
      }
    }

    final fixtures = <(int, int, int, String)>[];
    for (final pair in firstLeg) {
      fixtures.add((pair.$1, pair.$2, 1, 'ida'));
    }
    for (final pair in firstLeg) {
      fixtures.add((pair.$2, pair.$1, 2, 'vuelta'));
    }
    return fixtures;
  }

  String _groupName(int index) => String.fromCharCode('A'.codeUnitAt(0) + index);
}

List<int> advancingPositions(Tournament tournament) => tournament.advancingPositions;
                    
