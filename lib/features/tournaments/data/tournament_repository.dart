import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Modelo mínimo compartido por la lista, el detalle y la gestión de equipos.
/// Los campos tienen valores seguros para que documentos antiguos no rompan la UI.
class Tournament {
  const Tournament({
    required this.id,
    required this.name,
    required this.status,
    required this.currentRound,
    required this.totalRounds,
    required this.nextMatch,
    required this.isFavorite,
  });

  final String id;
  final String name;
  final String status;
  final int currentRound;
  final int totalRounds;
  final String nextMatch;
  final bool isFavorite;

  factory Tournament.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data() ?? <String, dynamic>{};
    return Tournament(
      id: snapshot.id,
      name: data['name'] as String? ?? 'Torneo sin nombre',
      status: data['status'] as String? ?? 'active',
      currentRound: (data['currentRound'] as num?)?.toInt() ?? 0,
      totalRounds: (data['totalRounds'] as num?)?.toInt() ?? 0,
      nextMatch: data['nextMatch'] as String? ?? 'Sin partido programado',
      isFavorite: (data['favoriteUserIds'] as List<dynamic>?)?.contains(FirebaseAuth.instance.currentUser?.uid) ?? false,
    );
  }
}

class Team {
  const Team({required this.id, required this.name, required this.members});

  final String id;
  final String name;
  final List<String> members;

  factory Team.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data() ?? <String, dynamic>{};
    return Team(
      id: snapshot.id,
      name: data['name'] as String? ?? 'Equipo sin nombre',
      members: (data['members'] as List<dynamic>?)?.whereType<String>().toList() ?? const [],
    );
  }
}

/// Aísla las consultas de Firestore del árbol de widgets y permite cambiar el
/// modelo de datos sin reescribir las pantallas. `participantIds` evita mostrar
/// torneos de otros usuarios y coincide con las reglas de acceso autenticado.
class TournamentRepository {
  TournamentRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Stream<List<Tournament>> watchMyTournaments() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(const []);
    return _firestore
        .collection('tournaments')
        .where('participantIds', arrayContains: uid)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(Tournament.fromSnapshot).toList());
  }

  Stream<List<Team>> watchTeams(String tournamentId) => _firestore
      .collection('tournaments')
      .doc(tournamentId)
      .collection('teams')
      .orderBy('name')
      .snapshots()
      .map((snapshot) => snapshot.docs.map(Team.fromSnapshot).toList());

  Future<void> toggleFavorite(Tournament tournament) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final reference = _firestore.collection('tournaments').doc(tournament.id);
    await reference.update({
      'favoriteUserIds': tournament.isFavorite
          ? FieldValue.arrayRemove([uid])
          : FieldValue.arrayUnion([uid]),
    });
  }

  Future<void> addTeam({required String tournamentId, required String name}) async {
    await _firestore.collection('tournaments').doc(tournamentId).collection('teams').add({
      'name': name.trim(),
      'members': <String>[],
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}

String firestoreErrorMessage(Object error) => error is FirebaseException
    ? error.message ?? 'No se pudo cargar la información.'
    : 'No se pudo cargar la información.';
