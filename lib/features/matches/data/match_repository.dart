import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/models/match_model.dart';

class MatchRepository {
    /// ES: Crea el repositorio con el cliente Firestore recibido o predeterminado.
    /// EN: Creates the repository with the supplied or default Firestore client.
  MatchRepository({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _firestore;

    /// ES: Emite documentos Firestore de partidos de un torneo.
    /// EN: Streams Firestore match documents for one tournament.
  Stream<QuerySnapshot<Map<String, dynamic>>> watchTournamentMatchDocuments(String tournamentId) => _firestore
      .collection('tournaments')
      .doc(tournamentId)
      .collection('matches')
      .snapshots();

    /// ES: Emite partidos de un torneo convertidos a modelos.
    /// EN: Streams a tournament's matches mapped to models.
  Stream<List<MatchModel>> watchTournamentMatches(String tournamentId) => _firestore
      .collection('tournaments')
      .doc(tournamentId)
      .collection('matches')
      .snapshots()
      .map((snapshot) => snapshot.docs.map(MatchModel.fromDocument).toList());

    /// ES: Emite partidos de todos los torneos mediante collectionGroup.
    /// EN: Streams matches across tournaments using a collection group query.
  Stream<List<MatchModel>> watchAllMatches() => _firestore
      .collectionGroup('matches')
      .snapshots()
      .map((snapshot) => snapshot.docs.map(MatchModel.fromDocument).toList());
}
