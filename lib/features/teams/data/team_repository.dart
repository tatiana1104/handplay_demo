import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/models/team_member_models.dart';

class TeamRepository {
  TeamRepository({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _firestore;

  Stream<QuerySnapshot<Map<String, dynamic>>> watchTournamentRegistrationDocuments(String tournamentId) => _firestore
      .collection('tournaments')
      .doc(tournamentId)
      .collection('registrations')
      .where('status', isEqualTo: 'approved')
      .snapshots();

  Stream<List<TeamRegistrationModel>> watchTournamentTeams(String tournamentId) => _firestore
      .collection('tournaments')
      .doc(tournamentId)
      .collection('registrations')
      .where('status', isEqualTo: 'approved')
      .snapshots()
      .map((snapshot) => snapshot.docs.map(TeamRegistrationModel.fromDocument).toList());

  Stream<List<TeamRegistrationModel>> watchAllApprovedTeams() => _firestore
      .collectionGroup('registrations')
      .where('status', isEqualTo: 'approved')
      .snapshots()
      .map((snapshot) => snapshot.docs.map(TeamRegistrationModel.fromDocument).toList());
}
