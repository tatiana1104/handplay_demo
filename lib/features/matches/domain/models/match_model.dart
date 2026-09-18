import 'package:cloud_firestore/cloud_firestore.dart';

/// Partido programado; los eventos y alineaciones viven como subcolecciones.
class MatchModel {
  const MatchModel({required this.id, required this.tournamentId, required this.categoryId, required this.venueId, required this.venue, required this.homeTeamId, required this.awayTeamId, required this.homeTeamName, required this.awayTeamName, required this.homeTeamColor, required this.awayTeamColor, required this.round, required this.phase, required this.scheduledAt, required this.homeScore, required this.awayScore, required this.status, required this.period, required this.elapsedSeconds});
  final String id;
  final String tournamentId;
  final String categoryId;
  final String venueId;
  final String venue;
  final String homeTeamId;
  final String awayTeamId;
  final String homeTeamName;
  final String awayTeamName;
  final dynamic homeTeamColor;
  final dynamic awayTeamColor;
  final int round;
  final String phase;
  final DateTime? scheduledAt;
  final int homeScore;
  final int awayScore;
  final String status;
  final String period;
  final int elapsedSeconds;

  factory MatchModel.fromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final scheduled = data['scheduledAt'];
    return MatchModel(id: doc.id, tournamentId: data['tournamentId'] as String? ?? '', categoryId: data['categoryId'] as String? ?? '', venueId: data['venueId'] as String? ?? '', venue: data['venue']?.toString() ?? data['sede']?.toString() ?? data['cancha']?.toString() ?? '', homeTeamId: data['homeTeamId']?.toString() ?? data['homeTeam']?.toString() ?? data['local']?.toString() ?? '', awayTeamId: data['awayTeamId']?.toString() ?? data['awayTeam']?.toString() ?? data['visitante']?.toString() ?? '', homeTeamName: data['homeTeamName']?.toString() ?? data['localName']?.toString() ?? '', awayTeamName: data['awayTeamName']?.toString() ?? data['visitorName']?.toString() ?? '', homeTeamColor: data['homeTeamColor'], awayTeamColor: data['awayTeamColor'], round: (data['round'] as num?)?.toInt() ?? 0, phase: data['phase'] as String? ?? '', scheduledAt: scheduled is Timestamp ? scheduled.toDate() : null, homeScore: (data['homeScore'] as num?)?.toInt() ?? 0, awayScore: (data['awayScore'] as num?)?.toInt() ?? 0, status: data['status'] as String? ?? 'scheduled', period: data['period'] as String? ?? '', elapsedSeconds: (data['elapsedSeconds'] as num?)?.toInt() ?? 0);
  }
}
