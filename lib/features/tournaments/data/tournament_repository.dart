import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/models/tournament_models.dart';

/// Punto único de acceso a las colecciones del torneo.
/// Mantiene las rutas Firestore alineadas con el modelo aprobado del ER.
class TournamentRepository {
  TournamentRepository({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _tournaments => _firestore.collection('tournaments');

  Stream<List<Tournament>> watchPublicTournaments() => _tournaments
      .snapshots()
      .map(_sortedTournaments);

  Stream<List<Tournament>> watchTournamentsForAdmin(String adminId) => _tournaments
      .where('adminId', isEqualTo: adminId)
      .snapshots()
      .map((snapshot) => _sortDocuments(snapshot));

  List<Tournament> _sortDocuments(QuerySnapshot<Map<String, dynamic>> snapshot) {
    final tournaments = snapshot.docs.map(Tournament.fromDocument).toList();
    tournaments.sort((a, b) {
      final aDate = a.startDate ?? DateTime(9999);
      final bDate = b.startDate ?? DateTime(9999);
      return aDate.compareTo(bDate);
    });
    return tournaments;
  }

  List<Tournament> _sortedTournaments(QuerySnapshot<Map<String, dynamic>> snapshot) => _sortDocuments(snapshot);

  Stream<List<TournamentCategory>> watchCategories(String tournamentId) => _tournaments
      .doc(tournamentId)
      .collection('categories')
      .orderBy('name')
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => TournamentCategory.fromDocument(doc, tournamentId)).toList());

  Stream<List<TournamentVenue>> watchVenues(String tournamentId) => _tournaments
      .doc(tournamentId)
      .collection('venues')
      .orderBy('name')
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => TournamentVenue.fromDocument(doc, tournamentId)).toList());

  Future<String> createTournament(Tournament tournament) async {
    final document = _tournaments.doc();
    await document.set(tournament.toFirestore());
    return document.id;
  }

  Future<void> updateTournament(Tournament tournament) => _tournaments.doc(tournament.id).update(tournament.toFirestore());

  Future<void> deleteTournament(String tournamentId) => _tournaments.doc(tournamentId).delete();
}
