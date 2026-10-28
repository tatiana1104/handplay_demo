import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/models/team_member_models.dart';

class TeamRepository {
    /// ES: Crea el repositorio con un cliente Firestore configurable.
    /// EN: Creates the repository with an injectable Firestore client.
  TeamRepository({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _firestore;

    /// ES: Emite resúmenes públicos de equipos aprobados de un torneo.
    /// EN: Streams public summaries for approved teams in one tournament.
    Stream<QuerySnapshot<Map<String, dynamic>>> watchTournamentPublicTeams(String tournamentId) => _firestore
      .collection('tournaments')
      .doc(tournamentId)
        .collection('public_teams')
      .where('status', isEqualTo: 'approved')
      .snapshots();

    /// ES: Emite resúmenes públicos aprobados como perfiles de equipo.
    /// EN: Streams approved public summaries as team profiles.
  Stream<List<TeamRegistrationModel>> watchTournamentTeams(String tournamentId) => _firestore
      .collection('tournaments')
      .doc(tournamentId)
      .collection('public_teams')
      .where('status', isEqualTo: 'approved')
      .snapshots()
      .map((snapshot) => snapshot.docs.map(TeamRegistrationModel.fromDocument).toList());

    /// ES: Emite resúmenes públicos aprobados de todos los torneos.
    /// EN: Streams approved public team summaries across all tournaments.
  Stream<List<TeamRegistrationModel>> watchAllApprovedTeams() => _firestore
      .collectionGroup('public_teams')
      .where('status', isEqualTo: 'approved')
      .snapshots()
      .map((snapshot) => snapshot.docs.map(TeamRegistrationModel.fromDocument).toList());
}
