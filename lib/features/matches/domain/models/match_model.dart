import 'package:cloud_firestore/cloud_firestore.dart';

/// ES: Partido programado; eventos y alineaciones viven en subcolecciones.
/// EN: Scheduled match; its events and lineups live in subcollections.
class MatchModel {
  /// ES: Crea un modelo de partido con sus equipos y estado.
  /// EN: Creates a match model with its teams and status.
  const MatchModel({
    required this.id,
    required this.tournamentId,
    required this.categoryId,
    required this.venueId,
    required this.venue,
    required this.homeTeamId,
    required this.awayTeamId,
    required this.homeTeamName,
    required this.awayTeamName,
    required this.homeTeamColor,
    required this.awayTeamColor,
    required this.round,
    required this.phase,
    required this.scheduledAt,
    required this.homeScore,
    required this.awayScore,
    required this.status,
    required this.period,
    required this.elapsedSeconds,
  });

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

  /// ES: Convierte un documento Firestore a un modelo de partido.
  /// EN: Converts a Firestore document into a match model.
  factory MatchModel.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    final scheduledAt = _dateValue(
      data['scheduledAt'] ?? data['date'] ?? data['fecha'],
    );

    return MatchModel(
      id: doc.id,
      tournamentId: _stringValue(data['tournamentId']),
      categoryId: _stringValue(data['categoryId']),
      venueId: _stringValue(data['venueId']),
      venue: _stringValue(
        data['venue'] ?? data['sede'] ?? data['cancha'],
      ),
      homeTeamId: _stringValue(
        data['homeTeamId'] ?? data['homeTeam'] ?? data['local'],
      ),
      awayTeamId: _stringValue(
        data['awayTeamId'] ?? data['awayTeam'] ?? data['visitante'],
      ),
      homeTeamName: _stringValue(data['homeTeamName'] ?? data['localName']),
      awayTeamName: _stringValue(
        data['awayTeamName'] ?? data['visitorName'] ?? data['visitanteName'],
      ),
      homeTeamColor: data['homeTeamColor'],
      awayTeamColor: data['awayTeamColor'],
      round: _intValue(data['round'] ?? data['jornada']),
      phase: _stringValue(data['phase']),
      scheduledAt: scheduledAt,
      homeScore: _intValue(data['homeScore']),
      awayScore: _intValue(data['awayScore']),
      status: _stringValue(data['status'], fallback: 'scheduled'),
      period: _stringValue(data['period']),
      elapsedSeconds: _intValue(data['elapsedSeconds']),
    );
  }
}

String _stringValue(dynamic value, {String fallback = ''}) =>
    value == null ? fallback : value.toString();

int _intValue(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime? _dateValue(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}
