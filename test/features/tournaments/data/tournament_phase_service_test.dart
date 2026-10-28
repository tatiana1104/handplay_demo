import 'package:flutter_test/flutter_test.dart';
import 'package:handplay_demo/features/tournaments/data/tournament_phase_service.dart';

void main() {
  test('generates one home-and-away fixture pair per team pairing', () {
    final fixtures = roundRobinFixtures(4);
    final firstLeg = fixtures.where((fixture) => fixture.$4 == 'ida').toList();

    expect(fixtures, hasLength(12));
    expect(firstLeg, hasLength(6));
    expect(firstLeg.map((fixture) => fixture.$3).toSet(), {1, 2, 3});

    for (var round = 1; round <= 3; round++) {
      final roundFixtures = firstLeg
          .where((fixture) => fixture.$3 == round)
          .toList();
      expect(roundFixtures, hasLength(2));
      final teamsInRound = [
        for (final fixture in roundFixtures) fixture.$1,
        for (final fixture in roundFixtures) fixture.$2,
      ];
      expect(teamsInRound.toSet(), hasLength(4));
    }

    for (final fixture in firstLeg) {
      expect(
        fixtures,
        contains((fixture.$2, fixture.$1, fixture.$3 + 3, 'vuelta')),
      );
    }
  });

  test('gives an odd-sized group one bye per matchday', () {
    final fixtures = roundRobinFixtures(3);

    expect(fixtures, hasLength(6));
    for (var round = 1; round <= 3; round++) {
      expect(fixtures.where((fixture) => fixture.$3 == round), hasLength(1));
    }
  });

  test('does not create fixtures for fewer than two teams', () {
    expect(roundRobinFixtures(0), isEmpty);
    expect(roundRobinFixtures(1), isEmpty);
  });
}
