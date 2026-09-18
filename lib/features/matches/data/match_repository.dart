import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/models/match_model.dart';

class MatchRepository {
  MatchRepository({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _firestore;

  Stream<List<MatchModel>> watchTournamentMatches(String tournamentId) => _firestore
      .collection('tournaments')
      .doc(tournamentId)
      .collection('matches')
      .snapshots()
      .map((snapshot) => snapshot.docs.map(MatchModel.fromDocument).toList());

  Stream<List<MatchModel>> watchAllMatches() => _firestore
      .collectionGroup('matches')
      .snapshots()
      .map((snapshot) => snapshot.docs.map(MatchModel.fromDocument).toList());
}
