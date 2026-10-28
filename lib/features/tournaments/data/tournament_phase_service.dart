import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/models/tournament_models.dart';

/// Assigns approved teams and creates first-phase round-robin fixtures.
class TournamentPhaseService {
  TournamentPhaseService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<void> assignPhaseOne(Tournament tournament) async {
    final tournamentRef = _firestore
        .collection('tournaments')
        .doc(tournament.id);
    final registrations = tournamentRef.collection('registrations');
    final matches = tournamentRef.collection('matches');
    final generationId =
        'phase1_${DateTime.now().microsecondsSinceEpoch}_${Random.secure().nextInt(1 << 32)}';

    await _claimGeneration(tournamentRef, generationId);
    try {
      final existing = await matches
          .where('phase', isEqualTo: 1)
          .limit(1)
          .get();
      if (existing.docs.isNotEmpty) {
        throw StateError(
          'La fase 1 ya tiene partidos. No se regeneró para conservar fechas, '
          'sedes, árbitros y resultados existentes.',
        );
      }

      final snapshot = await registrations
          .where('status', isEqualTo: 'approved')
          .get();
      final teams = snapshot.docs.toList()..shuffle(Random.secure());
      if (teams.length < 2) {
        throw StateError(
          'Se necesitan al menos dos equipos aprobados para generar la fase 1.',
        );
      }

      final groupCount = tournament.format == 'por_grupos'
          ? max(2, min(tournament.groupCount, teams.length))
          : 1;
      if (tournament.format == 'por_grupos' &&
          teams.length < groupCount * 2) {
        throw StateError(
          'Se necesitan al menos ${groupCount * 2} equipos aprobados para '
          'formar $groupCount grupos de dos o más equipos.',
        );
      }
      final groups = List.generate(
        groupCount,
        (_) => <DocumentSnapshot<Map<String, dynamic>>>[],
      );
      for (var index = 0; index < teams.length; index++) {
        groups[index % groupCount].add(teams[index]);
      }

      var matchBatch = _firestore.batch();
      var writesInBatch = 0;
      for (var groupIndex = 0; groupIndex < groups.length; groupIndex++) {
        final group = groups[groupIndex];
        final groupName = tournament.format == 'por_grupos'
            ? _groupName(groupIndex)
            : 'General';
        for (final fixture in roundRobinFixtures(group.length)) {
          final home = group[fixture.$1];
          final away = group[fixture.$2];
          final match = matches.doc();
          matchBatch.set(match, {
            'id': match.id,
            'phase': 1,
            'phaseOneGenerationId': generationId,
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
          writesInBatch++;
          if (writesInBatch == 450) {
            await matchBatch.commit();
            matchBatch = _firestore.batch();
            writesInBatch = 0;
          }
        }
      }
      if (writesInBatch > 0) await matchBatch.commit();

      var teamBatch = _firestore.batch();
      writesInBatch = 0;
      for (var groupIndex = 0; groupIndex < groups.length; groupIndex++) {
        final groupName = tournament.format == 'por_grupos'
            ? _groupName(groupIndex)
            : 'General';
        for (final team in groups[groupIndex]) {
          teamBatch.set(team.reference, {
            'phaseOneGroup': groupName,
            'phaseOnePosition': null,
            'phaseOneAssignedAt': FieldValue.serverTimestamp(),
            'phaseOneGenerationId': generationId,
          }, SetOptions(merge: true));
          writesInBatch++;
          if (writesInBatch == 450) {
            await teamBatch.commit();
            teamBatch = _firestore.batch();
            writesInBatch = 0;
          }
        }
      }
      if (writesInBatch > 0) await teamBatch.commit();

      await tournamentRef.update({
        'phaseOneGeneratedAt': FieldValue.serverTimestamp(),
      });
    } catch (error, stackTrace) {
      try {
        await _rollbackGeneration(
          tournamentRef,
          registrations,
          matches,
          generationId,
        );
      } on Object catch (rollbackError) {
        throw StateError(
          'No se pudo generar la fase 1 ($error) y la limpieza automática '
          'también falló ($rollbackError).',
        );
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<void> _claimGeneration(
    DocumentReference<Map<String, dynamic>> tournamentRef,
    String generationId,
  ) async {
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(tournamentRef);
      final data = snapshot.data();
      if (!snapshot.exists || data == null) {
        throw StateError('No se encontró el torneo.');
      }
      if (data['phaseOneGeneratedAt'] != null) {
        throw StateError(
          'La fase 1 ya fue generada. Edite los partidos existentes o contacte '
          'con administración si necesita corregirla.',
        );
      }
      final activeGeneration = data['phaseOneGenerationId'];
      final startedAt = data['phaseOneGenerationStartedAt'];
      if (activeGeneration != null) {
        final isStale =
            startedAt is Timestamp &&
            DateTime.now().difference(startedAt.toDate()) >
                const Duration(minutes: 10);
        if (!isStale) {
          throw StateError('La generación de la fase 1 ya está en proceso.');
        }
      }
      transaction.update(tournamentRef, {
        'phaseOneGenerationId': generationId,
        'phaseOneGenerationStartedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> _rollbackGeneration(
    DocumentReference<Map<String, dynamic>> tournamentRef,
    CollectionReference<Map<String, dynamic>> registrations,
    CollectionReference<Map<String, dynamic>> matches,
    String generationId,
  ) async {
    await _deleteGeneratedMatches(matches, generationId);
    final assignedTeams = await registrations
        .where('phaseOneGenerationId', isEqualTo: generationId)
        .get();
    for (var start = 0; start < assignedTeams.docs.length; start += 450) {
      final batch = _firestore.batch();
      final end = min(start + 450, assignedTeams.docs.length);
      for (final team in assignedTeams.docs.sublist(start, end)) {
        batch.update(team.reference, {
          'phaseOneGroup': FieldValue.delete(),
          'phaseOnePosition': FieldValue.delete(),
          'phaseOneAssignedAt': FieldValue.delete(),
          'phaseOneGenerationId': FieldValue.delete(),
        });
      }
      await batch.commit();
    }
    await _firestore.runTransaction((transaction) async {
      final current = await transaction.get(tournamentRef);
      if (current.data()?['phaseOneGenerationId'] == generationId) {
        transaction.update(tournamentRef, {
          'phaseOneGenerationId': FieldValue.delete(),
          'phaseOneGenerationStartedAt': FieldValue.delete(),
        });
      }
    });
  }

  Future<void> _deleteGeneratedMatches(
    CollectionReference<Map<String, dynamic>> matches,
    String generationId,
  ) async {
    while (true) {
      final generated = await matches
          .where('phaseOneGenerationId', isEqualTo: generationId)
          .limit(450)
          .get();
      if (generated.docs.isEmpty) return;
      final batch = _firestore.batch();
      for (final match in generated.docs) {
        batch.delete(match.reference);
      }
      await batch.commit();
    }
  }

  String _groupName(int index) =>
      String.fromCharCode('A'.codeUnitAt(0) + index);
}

List<(int, int, int, String)> roundRobinFixtures(int teamCount) {
  if (teamCount < 2) return [];

  final slots = List<int?>.generate(teamCount, (index) => index);
  if (slots.length.isOdd) slots.add(null);
  final roundCount = slots.length - 1;
  final firstLeg = <(int, int, int, String)>[];

  for (var round = 0; round < roundCount; round++) {
    for (var slot = 0; slot < slots.length ~/ 2; slot++) {
      var home = slots[slot];
      var away = slots[slots.length - 1 - slot];
      if (home == null || away == null) continue;
      if ((round + slot).isOdd) {
        final previousHome = home;
        home = away;
        away = previousHome;
      }
      firstLeg.add((home, away, round + 1, 'ida'));
    }

    final lastSlot = slots.removeLast();
    slots.insert(1, lastSlot);
  }

  return [
    ...firstLeg,
    for (final fixture in firstLeg)
      (fixture.$2, fixture.$1, fixture.$3 + roundCount, 'vuelta'),
  ];
}

List<int> advancingPositions(Tournament tournament) =>
    tournament.advancingPositions;
