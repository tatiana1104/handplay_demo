import 'package:cloud_firestore/cloud_firestore.dart';

class PlayerModel {
  const PlayerModel({required this.id, required this.name, this.document, this.number, this.position, this.gender});
  final String id;
  final String name;
  final String? document;
  final String? number;
  final String? position;
  final String? gender;

  factory PlayerModel.fromMap(Map<String, dynamic> data, {String id = ''}) => PlayerModel(
        id: id,
        name: data['name']?.toString() ?? data['fullName']?.toString() ?? 'Jugador sin nombre',
        document: data['document']?.toString(),
        number: data['number']?.toString(),
        position: data['position']?.toString(),
        gender: data['gender']?.toString(),
      );
}

class CoachModel {
  const CoachModel({required this.id, required this.name, this.email, this.phone});
  final String id;
  final String name;
  final String? email;
  final String? phone;

  factory CoachModel.fromMap(Map<String, dynamic> data, {String id = ''}) => CoachModel(
        id: id,
        name: data['coachName']?.toString() ?? data['name']?.toString() ?? 'Entrenador sin nombre',
        email: data['coachEmail']?.toString() ?? data['email']?.toString(),
        phone: data['coachPhone']?.toString() ?? data['phone']?.toString(),
      );
}

class TeamRegistrationModel {
  const TeamRegistrationModel({required this.id, required this.name, required this.uniformColor, required this.players, required this.coach});
  final String id;
  final String name;
  final dynamic uniformColor;
  final List<PlayerModel> players;
  final CoachModel coach;

  factory TeamRegistrationModel.fromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final rawPlayers = data['players'] is List ? (data['players'] as List) : const [];
    return TeamRegistrationModel(
      id: doc.id,
      name: data['teamName']?.toString() ?? data['clubName']?.toString() ?? data['name']?.toString() ?? 'Equipo sin nombre',
      uniformColor: data['uniformColor'] ?? data['jerseyColor'] ?? data['color'],
      players: rawPlayers.whereType<Map>().map((player) => PlayerModel.fromMap(Map<String, dynamic>.from(player))).toList(),
      coach: CoachModel.fromMap(data),
    );
  }
}
