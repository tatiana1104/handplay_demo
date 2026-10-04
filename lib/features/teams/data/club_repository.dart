import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/models/club_model.dart';

/// ES: Centraliza las lecturas y escrituras de clubes oficiales.
/// EN: Centralizes reads and writes for official clubs.
class ClubRepository {
  /// ES: Crea el repositorio con Firestore inyectado o su instancia global.
  /// EN: Creates the repository with an injected or default Firestore client.
  ClubRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _clubs =>
      _firestore.collection('clubs');

  /// ES: Emite los clubes ordenados por nombre para listas y selectores.
  /// EN: Streams clubs ordered by name for lists and dropdowns.
  Stream<List<ClubModel>> watchClubs() => _clubs
      .orderBy('name')
      .snapshots()
      .map((snapshot) => snapshot.docs.map(ClubModel.fromDocument).toList());

  /// ES: Crea un club oficial y registra quién lo creó.
  /// EN: Creates an official club and records who created it.
  Future<void> createClub({required String name, required String createdBy, String assistantName = '', String assistantEmail = ''}) {
    final document = _clubs.doc();
    return document.set({
      'name': name.trim(),
      'assistantName': assistantName.trim(),
      'assistantEmail': assistantEmail.trim().toLowerCase(),
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// ES: Actualiza el nombre de un club sin cambiar sus metadatos de creación.
  /// EN: Updates a club name without changing its creation metadata.
  Future<void> updateClub(ClubModel club) => _clubs.doc(club.id).update({
    'name': club.name.trim(),
    'assistantName': club.assistantName.trim(),
    'assistantEmail': club.assistantEmail.trim().toLowerCase(),
    'updatedAt': FieldValue.serverTimestamp(),
  });

  /// ES: Elimina el club oficial seleccionado.
  /// EN: Deletes the selected official club.
  Future<void> deleteClub(String clubId) => _clubs.doc(clubId).delete();
}
