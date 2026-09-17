import 'package:cloud_firestore/cloud_firestore.dart';

/// Partido programado; los eventos y alineaciones viven como subcolecciones.
class MatchModel {
  const MatchModel({required this.id, required this.tournamentId, required this.categoryId, required this.venueId, required this.homeTeamId, required this.awayTeamId, required this.round, required this.phase, required this.scheduledAt, required this.homeScore, required this.awayScore, required this.status, required this.period, required this.elapsedSeconds});
  final String id;
  final String tournamentId;
  final String categoryId;
  final String venueId;
  final String homeTeamId;
  final String awayTeamId;
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
    return MatchModel(id: doc.id, tournamentId: data['tournamentId'] as String? ?? '', categoryId: data['categoryId'] as String? ?? '', venueId: data['venueId'] as String? ?? '', homeTeamId: data['homeTeamId'] as String? ?? '', awayTeamId: data['awayTeamId'] as String? ?? '', round: (data['round'] as num?)?.toInt() ?? 0, phase: data['phase'] as String? ?? '', scheduledAt: scheduled is Timestamp ? scheduled.toDate() : null, homeScore: (data['homeScore'] as num?)?.toInt() ?? 0, awayScore: (data['awayScore'] as num?)?.toInt() ?? 0, status: data['status'] as String? ?? 'scheduled', period: data['period'] as String? ?? '', elapsedSeconds: (data['elapsedSeconds'] as num?)?.toInt() ?? 0);
  }
}
