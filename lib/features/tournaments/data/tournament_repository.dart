import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/models/tournament_models.dart';

/// Punto único de acceso a las colecciones del torneo.
/// Mantiene las rutas Firestore alineadas con el modelo aprobado del ER.
class TournamentRepository {
  /// ES: Crea el repositorio con el cliente Firestore recibido o predeterminado.
  /// EN: Creates the repository with the supplied or default Firestore client.
  TournamentRepository({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// ES: Expone la colección raíz de torneos.
  /// EN: Provides the root tournaments collection.
  CollectionReference<Map<String, dynamic>> get _tournaments => _firestore.collection('tournaments');

  /// ES: Emite los torneos públicos ordenados por fecha de inicio.
  /// EN: Streams public tournaments in start-date order.
  Stream<List<Tournament>> watchPublicTournaments() => _tournaments
      .snapshots()
      .map(_sortedTournaments);

  /// ES: Emite los torneos del administrador indicado.
  /// EN: Streams tournaments owned by the specified administrator.
  Stream<List<Tournament>> watchTournamentsForAdmin(String adminId) => _tournaments
      .where('adminId', isEqualTo: adminId)
      .snapshots()
      .map((snapshot) => _sortDocuments(snapshot));

  /// ES: Convierte y ordena resultados de torneos por fecha de inicio.
  /// EN: Converts and sorts tournament query results by start date.
  List<Tournament> _sortDocuments(QuerySnapshot<Map<String, dynamic>> snapshot) {
    final tournaments = snapshot.docs.map(Tournament.fromDocument).toList();
    tournaments.sort((a, b) {
      final aDate = a.startDate ?? DateTime(9999);
      final bDate = b.startDate ?? DateTime(9999);
      return aDate.compareTo(bDate);
    });
    return tournaments;
  }

  /// ES: Ordena los modelos recibidos de la consulta pública.
  /// EN: Sorts models from the public tournament query.
  List<Tournament> _sortedTournaments(QuerySnapshot<Map<String, dynamic>> snapshot) => _sortDocuments(snapshot);

  /// ES: Emite las categorías de un torneo en orden alfabético.
  /// EN: Streams a tournament's categories alphabetically.
  Stream<List<TournamentCategory>> watchCategories(String tournamentId) => _tournaments
      .doc(tournamentId)
      .collection('categories')
      .orderBy('name')
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => TournamentCategory.fromDocument(doc, tournamentId)).toList());

  /// ES: Emite las sedes de un torneo en orden alfabético.
  /// EN: Streams a tournament's venues alphabetically.
  Stream<List<TournamentVenue>> watchVenues(String tournamentId) => _tournaments
      .doc(tournamentId)
      .collection('venues')
      .orderBy('name')
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => TournamentVenue.fromDocument(doc, tournamentId)).toList());

  /// ES: Crea el documento del torneo y devuelve su ID generado.
  /// EN: Creates a tournament document and returns its generated ID.
  Future<String> createTournament(Tournament tournament) async {
    final document = _tournaments.doc();
    await document.set(tournament.toFirestore());
    return document.id;
  }

  /// ES: Actualiza un torneo guardado con los valores actuales del modelo.
  /// EN: Updates a saved tournament with the model's current values.
  Future<void> updateTournament(Tournament tournament) => _tournaments.doc(tournament.id).update(tournament.toFirestore());

  /// ES: Elimina el documento del torneo indicado.
  /// EN: Deletes the specified tournament document.
  Future<void> deleteTournament(String tournamentId) => _tournaments.doc(tournamentId).delete();
}
