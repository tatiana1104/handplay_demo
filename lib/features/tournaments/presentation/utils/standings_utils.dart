import 'package:cloud_firestore/cloud_firestore.dart';

String teamLabel(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data();
  final team = data['team'];
  if (team is Map) return (team['name'] ?? team['teamName'] ?? team['id'] ?? doc.id).toString();
  return (data['teamName'] ?? data['name'] ?? data['team'] ?? doc.id).toString();
}

int stat(QueryDocumentSnapshot<Map<String, dynamic>> doc, String key) {
  final data = doc.data();
  const aliases = <String, List<String>>{
    'points': ['points', 'pts', 'score'],
    'played': ['played', 'matchesPlayed', 'gamesPlayed', 'pj'],
    'wins': ['wins', 'won', 'matchesWon', 'pg'],
    'draws': ['draws', 'ties', 'matchesDrawn', 'pe'],
    'losses': ['losses', 'lost', 'matchesLost', 'pp'],
    'goalsFor': ['goalsFor', 'goalsScored', 'gf'],
    'goalsAgainst': ['goalsAgainst', 'goalsConceded', 'gc'],
  };
  for (final field in aliases[key] ?? [key]) {
    final value = data[field];
    if (value is num) return value.toInt();
    final parsed = int.tryParse(value?.toString() ?? '');
    if (parsed != null) return parsed;
  }
  return 0;
}

int points(QueryDocumentSnapshot<Map<String, dynamic>> doc) => stat(doc, 'points');

List<QueryDocumentSnapshot<Map<String, dynamic>>> sortedStandings(
  List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
) {
  final sorted = [...docs];
  int goalDifference(QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
      stat(doc, 'goalsFor') - stat(doc, 'goalsAgainst');

  sorted.sort((a, b) {
    final byPoints = points(b).compareTo(points(a));
    if (byPoints != 0) return byPoints;
    final byWins = stat(b, 'wins').compareTo(stat(a, 'wins'));
    if (byWins != 0) return byWins;
    final byDifference = goalDifference(b).compareTo(goalDifference(a));
    if (byDifference != 0) return byDifference;
    final byGoalsFor = stat(b, 'goalsFor').compareTo(stat(a, 'goalsFor'));
    if (byGoalsFor != 0) return byGoalsFor;
    return stat(a, 'losses').compareTo(stat(b, 'losses'));
  });
  return sorted;
}
