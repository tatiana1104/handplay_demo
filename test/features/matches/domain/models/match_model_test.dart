// ignore_for_file: subtype_of_sealed_class

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handplay_demo/features/matches/domain/models/match_model.dart';
import 'package:mocktail/mocktail.dart';

class _MockMatchDocument extends Mock
    implements DocumentSnapshot<Map<String, dynamic>> {}

void main() {
  late _MockMatchDocument document;

  setUp(() {
    document = _MockMatchDocument();
    when(() => document.id).thenReturn('match-1');
  });

  test('maps generated fixture round and numeric phase', () {
    when(() => document.data()).thenReturn({
      'phase': 1,
      'jornada': 2,
      'homeTeamId': 'team-a',
      'awayTeamId': 'team-b',
    });

    final match = MatchModel.fromDocument(document);

    expect(match.id, 'match-1');
    expect(match.phase, '1');
    expect(match.round, 2);
    expect(match.homeTeamId, 'team-a');
    expect(match.awayTeamId, 'team-b');
    expect(match.scheduledAt, isNull);
  });

  test('maps scheduled date and legacy string fields', () {
    final scheduledAt = DateTime(2026, 10, 28, 17);
    when(() => document.data()).thenReturn({
      'phase': 'final',
      'round': '3',
      'date': Timestamp.fromDate(scheduledAt),
      'homeTeam': 'team-a',
      'visitante': 'team-b',
      'venue': 'Cancha central',
    });

    final match = MatchModel.fromDocument(document);

    expect(match.phase, 'final');
    expect(match.round, 3);
    expect(match.scheduledAt, scheduledAt);
    expect(match.homeTeamId, 'team-a');
    expect(match.awayTeamId, 'team-b');
    expect(match.venue, 'Cancha central');
  });
}
