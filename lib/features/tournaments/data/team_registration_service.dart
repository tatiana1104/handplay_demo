import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// ES: Resultado que la pantalla necesita tras guardar la inscripción.
/// EN: Result needed by the screen after saving a registration.
class TeamRegistrationResult {
  /// ES: Crea el resultado de cuenta e invitación del entrenador.
  /// EN: Creates a result describing coach-account and invitation outcomes.
  const TeamRegistrationResult({
    required this.isCoachAccount,
    required this.coachLinkSent,
  });

  final bool isCoachAccount;
  final bool coachLinkSent;
}

/// ES: Guarda la inscripción y ejecuta operaciones relacionadas en Firebase.
/// EN: Persists the registration and performs related Firebase operations.
class TeamRegistrationService {
  /// ES: Crea el servicio con clientes Firebase recibidos o predeterminados.
  /// EN: Creates the service with supplied or default Firebase clients.
  TeamRegistrationService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  /// ES: Guarda la solicitud, indexa sus personas e invita al entrenador si corresponde.
  /// EN: Saves the request, indexes its people, and optionally invites its coach.
  Future<TeamRegistrationResult> submit({
    required String tournamentId,
    required String? registrationId,
    required String teamName,
    required List<String> clubs,
    required String coachName,
    required String coachDocument,
    required String coachPhone,
    required String clubEmail,
    required String? category,
    required String uniformColor,
    required List<Map<String, String>> players,
  }) async {
    final normalizedClubEmail = clubEmail.trim().toLowerCase();
    final normalizedCoachDocument = _normalizeDocument(coachDocument);
    final enrichedPlayers = await _enrichPlayers(players);
    final currentUser = _auth.currentUser;
    // The requested email belongs to the club, never to the coach.
    final isCoachAccount = false;
    final registrations = _firestore
        .collection('tournaments')
        .doc(tournamentId)
        .collection('registrations');
    final registration = registrationId == null
        ? registrations.doc()
        : registrations.doc(registrationId);
    final teamData = {
      'id': registration.id,
      'tournamentId': tournamentId,
      'registrationId': registration.id,
      'teamName': teamName.trim(),
      'clubName': clubs.join(', '),
      'clubs': List<String>.from(clubs),
      'coachName': coachName.trim(),
      'coachDocument': coachDocument.trim(),
      'coachPhone': coachPhone.trim(),
      'clubEmail': normalizedClubEmail,
      'category': category,
      'uniformColor': uniformColor,
      'logoUrl': null,
      'players': enrichedPlayers,
      'playerCount': players.length,
      'status': 'pending',
      if (registrationId == null) 'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      if (registrationId != null) 'rejectionReason': FieldValue.delete(),
      if (isCoachAccount) 'coachUid': currentUser!.uid,
    };
    final registrationBatch = _firestore.batch();
    final directoryBatch = _firestore.batch();
    final users = _firestore.collection('users');
    final profileDirectory = _firestore.collection('profile_directory');
    _addClubUser(
      directoryBatch: directoryBatch,
      users: users,
      profileDirectory: profileDirectory,
      clubName: clubs.join(', '),
      email: normalizedClubEmail,
    );

    final coachIsAlsoPlayer = enrichedPlayers.any(
      (player) =>
          _normalizeDocument(player['document'] ?? '') ==
              normalizedCoachDocument &&
          normalizedCoachDocument.isNotEmpty,
    );
    if (!coachIsAlsoPlayer) {
      _addDirectoryUser(
        directoryBatch: directoryBatch,
        users: users,
        profileDirectory: profileDirectory,
        name: coachName,
        document: normalizedCoachDocument,
        roles: const ['entrenador'],
        email: null,
        phone: coachPhone,
        extra: {
          'teamName': teamName.trim(),
          'clubName': clubs.join(', '),
          'clubEmail': normalizedClubEmail,
        },
      );
    }
    for (final player in enrichedPlayers) {
      final playerDocument = player['document'] ?? '';
      final isCoachPlayer =
          playerDocument == normalizedCoachDocument &&
          normalizedCoachDocument.isNotEmpty;
      _addDirectoryUser(
        directoryBatch: directoryBatch,
        users: users,
        profileDirectory: profileDirectory,
        name: player['name'] ?? '',
        document: playerDocument,
        roles: isCoachPlayer
            ? const ['entrenador', 'jugador']
            : const ['jugador'],
        extra: {
          'number': player['number'] ?? '',
          'shirtNumber': player['number'] ?? '',
          'position': player['position'] ?? '',
          'gender': player['gender'] ?? '',
          'club': player['club'] ?? '',
          'teamName': teamName.trim(),
        },
      );
    }

    registrationBatch.set(registration, {
      ...teamData,
      'verificationMessage':
          'Solicitud recibida. Debes esperar a que el administrador verifique la información.',
      'termsAccepted': true,
    }, SetOptions(merge: true));
    if (isCoachAccount) {
      registrationBatch.set(profileDirectory.doc(currentUser!.uid), {
        'name': coachName.trim(),
        'document': coachDocument.trim(),
        'email': null,
        'phone': coachPhone.trim(),
        'roles': FieldValue.arrayUnion(
          coachIsAlsoPlayer ? ['entrenador', 'jugador'] : ['entrenador'],
        ),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      registrationBatch.set(users.doc(currentUser.uid), {
        'uid': currentUser.uid,
        'email': currentUser.email,
        'nombre': coachName.trim(),
        'roles': FieldValue.arrayUnion(
          coachIsAlsoPlayer ? ['entrenador', 'jugador'] : ['entrenador'],
        ),
        'rol': 'entrenador',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      registrationBatch.set(
        _firestore
            .collection('tournaments')
            .doc(tournamentId)
            .collection('teams')
            .doc(registration.id),
        teamData,
        SetOptions(merge: true),
      );
    }

    await registrationBatch.commit().timeout(
      const Duration(seconds: 20),
      onTimeout: () => throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'deadline-exceeded',
        message:
            'La conexión con Firebase tardó demasiado. Comprueba tu conexión e inténtalo de nuevo.',
      ),
    );
    try {
      await directoryBatch.commit();
    } on FirebaseException catch (error) {
      debugPrint(
        '[handplay] No se pudieron sincronizar perfiles del directorio: ${error.code}',
      );
    }

    const coachLinkSent = false;

    return TeamRegistrationResult(
      isCoachAccount: isCoachAccount,
      coachLinkSent: coachLinkSent,
    );
  }

  /// ES: Completa cada jugador con los datos encontrados en el directorio.
  /// EN: Enriches each submitted player with matching directory data.
  Future<List<Map<String, String>>> _enrichPlayers(
    List<Map<String, String>> players,
  ) async {
    final enrichedPlayers = <Map<String, String>>[];
    final directory = _firestore.collection('profile_directory');
    for (final player in players) {
      final document = player['document']?.trim() ?? '';
      final documentValues = <dynamic>{
        document,
        int.tryParse(document),
      }.where((value) => value != null).toList();
      var matches = await directory
          .where('document', isEqualTo: document)
          .limit(1)
          .get();
      if (matches.docs.isEmpty && documentValues.length > 1) {
        matches = await directory
            .where('document', isEqualTo: documentValues.last)
            .limit(1)
            .get();
      }
      final matchesByNumber = matches.docs.isEmpty
          ? await directory
                .where('documentNumber', isEqualTo: document)
                .limit(1)
                .get()
          : matches;
      final existing = matchesByNumber.docs.isEmpty
          ? null
          : matchesByNumber.docs.first.data();
      enrichedPlayers.add({
        ...?existing?.map(
          (key, value) => MapEntry(key, value?.toString() ?? ''),
        ),
        ...player,
        'document': document,
      });
    }
    return enrichedPlayers;
  }

  /// ES: Agrega al batch los perfiles mínimos de una persona.
  /// EN: Queues one person's minimal user and directory records in a batch.
  void _addDirectoryUser({
    required WriteBatch directoryBatch,
    required CollectionReference<Map<String, dynamic>> users,
    required CollectionReference<Map<String, dynamic>> profileDirectory,
    required String name,
    required String document,
    required List<String> roles,
    String? email,
    String? phone,
    Map<String, dynamic> extra = const {},
  }) {
    final normalizedDocument = _normalizeDocument(document);
    if (normalizedDocument.isEmpty) return;
    final userRef = users.doc('document_$normalizedDocument');
    final directoryRef = profileDirectory.doc('document_$normalizedDocument');
    final data = <String, dynamic>{
      'uid': userRef.id,
      'displayName': name.trim(),
      'nombre': name.trim(),
      'document': normalizedDocument,
      'email': email?.trim().toLowerCase() ?? '',
      'phone': phone?.trim() ?? '',
      'roles': FieldValue.arrayUnion(roles),
      ...extra,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    directoryBatch.set(userRef, data, SetOptions(merge: true));
    directoryBatch.set(directoryRef, data, SetOptions(merge: true));
  }

  void _addClubUser({
    required WriteBatch directoryBatch,
    required CollectionReference<Map<String, dynamic>> users,
    required CollectionReference<Map<String, dynamic>> profileDirectory,
    required String clubName,
    required String email,
  }) {
    if (email.isEmpty) return;
    final key = email.replaceAll(RegExp(r'[^a-z0-9]'), '_');
    final data = <String, dynamic>{
      'uid': 'club_$key',
      'displayName': clubName.trim(),
      'clubName': clubName.trim(),
      'email': email,
      'roles': ['club'],
      'updatedAt': FieldValue.serverTimestamp(),
    };
    directoryBatch.set(users.doc('club_$key'), data, SetOptions(merge: true));
    directoryBatch.set(profileDirectory.doc('club_$key'), data, SetOptions(merge: true));
  }

  /// ES: Elimina puntuación y diferencias de mayúsculas en documentos.
  /// EN: Removes punctuation and casing differences from identity documents.
  /// ES: Elimina puntuación y diferencias de mayúsculas en documentos.
  /// EN: Removes punctuation and casing differences from identity documents.
  String _normalizeDocument(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
}
