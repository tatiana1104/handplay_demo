import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/models/team_member_models.dart';

class TeamRepository {
    /// ES: Crea el repositorio con un cliente Firestore configurable.
    /// EN: Creates the repository with an injectable Firestore client.
  TeamRepository({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _firestore;

    /// ES: Emite documentos de inscripción aprobados de un torneo.
    /// EN: Streams approved registration documents for one tournament.
  Stream<QuerySnapshot<Map<String, dynamic>>> watchTournamentRegistrationDocuments(String tournamentId) => _firestore
      .collection('tournaments')
      .doc(tournamentId)
      .collection('registrations')
      .where('status', isEqualTo: 'approved')
      .snapshots();

    /// ES: Emite inscripciones aprobadas convertidas a perfiles de equipo.
    /// EN: Streams approved registrations mapped to team profiles.
  Stream<List<TeamRegistrationModel>> watchTournamentTeams(String tournamentId) => _firestore
      .collection('tournaments')
      .doc(tournamentId)
      .collection('registrations')
      .where('status', isEqualTo: 'approved')
      .snapshots()
      .map((snapshot) => snapshot.docs.map(TeamRegistrationModel.fromDocument).toList());

    /// ES: Emite las inscripciones aprobadas de todos los torneos.
    /// EN: Streams approved team registrations across all tournaments.
  Stream<List<TeamRegistrationModel>> watchAllApprovedTeams() => _firestore
      .collectionGroup('registrations')
      .where('status', isEqualTo: 'approved')
      .snapshots()
      .map((snapshot) => snapshot.docs.map(TeamRegistrationModel.fromDocument).toList());
}
