import 'package:cloud_firestore/cloud_firestore.dart';

/// Equipo inscrito en una categoría del torneo.
class TeamModel {
  /// ES: Crea un modelo de equipo con sus campos de dominio.
  /// EN: Creates a team model from its domain fields.
  const TeamModel({required this.id, required this.categoryId, required this.clubId, required this.name, required this.status, required this.playerCount});
  final String id;
  final String categoryId;
  final String clubId;
  final String name;
  final String status;
  final int playerCount;

  /// ES: Convierte un documento Firestore de equipo al modelo de dominio.
  /// EN: Maps a Firestore team document into the domain model.
  factory TeamModel.fromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return TeamModel(id: doc.id, categoryId: data['categoryId'] as String? ?? '', clubId: data['clubId'] as String? ?? '', name: data['name'] as String? ?? '', status: data['status'] as String? ?? 'pending', playerCount: (data['playerCount'] as num?)?.toInt() ?? 0);
  }
}

/// Jugador inscrito dentro de un equipo.
class PlayerModel {
  /// ES: Crea un registro de jugador asociado a un equipo.
  /// EN: Creates a player record associated with a team.
  const PlayerModel({required this.id, required this.teamId, required this.userId, required this.name, required this.position, required this.gender});
  final String id;
  final String teamId;
  final String userId;
  final String name;
  final String position;
  final String gender;

  /// ES: Convierte un documento Firestore de jugador al modelo de dominio.
  /// EN: Maps a Firestore player document into the domain model.
  factory PlayerModel.fromDocument(DocumentSnapshot<Map<String, dynamic>> doc, String teamId) {
    final data = doc.data() ?? const <String, dynamic>{};
    return PlayerModel(id: doc.id, teamId: teamId, userId: data['userId'] as String? ?? '', name: data['name'] as String? ?? '', position: data['position'] as String? ?? '', gender: data['gender'] as String? ?? '');
  }
}
