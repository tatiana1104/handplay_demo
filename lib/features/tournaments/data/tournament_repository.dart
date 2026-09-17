import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/models/tournament_models.dart';

/// Punto único de acceso a las colecciones del torneo.
/// Mantiene las rutas Firestore alineadas con el modelo aprobado del ER.
class TournamentRepository {
  TournamentRepository({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _tournaments => _firestore.collection('tournaments');

  Stream<List<Tournament>> watchTournamentsForAdmin(String adminId) => _tournaments
      .where('adminId', isEqualTo: adminId)
      .orderBy('startDate')
      .snapshots()
      .map((snapshot) => snapshot.docs.map(Tournament.fromDocument).toList());

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
}
