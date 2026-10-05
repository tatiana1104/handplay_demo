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
  Future<void> createClub({required String name, required String email, required String createdBy, String assistantName = '', String assistantEmail = ''}) {
    final document = _clubs.doc();
    final normalizedEmail = email.trim().toLowerCase();
    final userId = 'club_${normalizedEmail.replaceAll(RegExp(r'[^a-z0-9]'), '_')}';
    final batch = _firestore.batch();
    batch.set(document, {
      'name': name.trim(),
      'email': normalizedEmail,
      'assistantName': assistantName.trim(),
      'assistantEmail': assistantEmail.trim().toLowerCase(),
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    final userData = {
      'uid': userId,
      'displayName': name.trim(),
      'nombre': name.trim(),
      'email': normalizedEmail,
      'clubId': document.id,
      'clubName': name.trim(),
      'roles': ['club'],
      'rol': 'club',
      'updatedAt': FieldValue.serverTimestamp(),
    };
    batch.set(_firestore.collection('users').doc(userId), userData, SetOptions(merge: true));
    batch.set(_firestore.collection('profile_directory').doc(userId), userData, SetOptions(merge: true));
    return batch.commit();
  }

  /// ES: Actualiza el nombre de un club sin cambiar sus metadatos de creación.
  /// EN: Updates a club name without changing its creation metadata.
  Future<void> updateClub(ClubModel club) {
    final normalizedEmail = club.email.trim().toLowerCase();
    final userId = 'club_${normalizedEmail.replaceAll(RegExp(r'[^a-z0-9]'), '_')}';
    final batch = _firestore.batch();
    batch.update(_clubs.doc(club.id), {
    'name': club.name.trim(),
    'email': normalizedEmail,
    'assistantName': club.assistantName.trim(),
    'assistantEmail': club.assistantEmail.trim().toLowerCase(),
    'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.set(_firestore.collection('users').doc(userId), {
      'uid': userId,
      'displayName': club.name.trim(),
      'nombre': club.name.trim(),
      'email': normalizedEmail,
      'clubId': club.id,
      'clubName': club.name.trim(),
      'roles': ['club'],
      'rol': 'club',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return batch.commit();
  }

  /// ES: Elimina el club oficial seleccionado.
  /// EN: Deletes the selected official club.
  Future<void> deleteClub(String clubId) => _clubs.doc(clubId).delete();
}
