import 'package:cloud_firestore/cloud_firestore.dart';

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
  TeamRegistrationService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

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
    required String coachEmail,
    required String clubEmail,
    required String? category,
    required String uniformColor,
    required List<Map<String, String>> players,
  }) async {
    final normalizedClubEmail = clubEmail.trim().toLowerCase();
    final normalizedCoachEmail = coachEmail.trim().toLowerCase();
    final registrationPlayers = players
        .map((player) => Map<String, String>.from(player))
        .toList();
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
      'coachEmail': normalizedCoachEmail,
      'clubEmail': normalizedClubEmail,
      'category': category,
      'uniformColor': uniformColor,
      'logoUrl': null,
      'players': registrationPlayers,
      'playerCount': registrationPlayers.length,
      'status': 'pending',
      if (registrationId == null) 'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      if (registrationId != null) 'rejectionReason': FieldValue.delete(),
    };
    final registrationBatch = _firestore.batch();

    registrationBatch.set(registration, {
      ...teamData,
      'verificationMessage':
          'Solicitud recibida. Debes esperar a que el administrador verifique la información.',
      'termsAccepted': true,
    }, SetOptions(merge: true));

    await registrationBatch.commit().timeout(
      const Duration(seconds: 20),
      onTimeout: () => throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'deadline-exceeded',
        message:
            'La conexión con Firebase tardó demasiado. Comprueba tu conexión e inténtalo de nuevo.',
      ),
    );

    return TeamRegistrationResult(isCoachAccount: false, coachLinkSent: false);
  }
}
