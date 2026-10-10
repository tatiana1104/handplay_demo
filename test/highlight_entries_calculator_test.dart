import 'package:flutter_test/flutter_test.dart';
import 'package:handplay_demo/features/tournaments/presentation/utils/highlight_entries_calculator.dart';

// Datos mínimos: dos equipos aprobados y un partido finalizado.
HighlightRegistration team(
  String id,
  String name,
  List<Map<String, dynamic>> players,
) => (
  id: id,
  data: {'teamName': name, 'status': 'approved', 'players': players},
);

Map<String, dynamic> finishedMatch({
  required List<Map<String, dynamic>> events,
  int home = 0,
  int away = 0,
}) => {
  'status': 'finished',
  'lineupStatus': 'approved',
  'homeTeamId': 'a',
  'awayTeamId': 'b',
  'finalHomeScore': home,
  'finalAwayScore': away,
  'finalEvents': events,
};

Map<String, dynamic> goal(String team, String name) => {
  'type': 'goal',
  'team': team,
  'player': '7-$name',
  'playerName': name,
};

void main() {
  group('Bug 1: jugador sin género', () {
    test('no entra en ninguna de las dos tablas', () {
      final registrations = [
        team('a', 'Halcones', [
          {'name': 'Sin Genero', 'position': 'Central'},
          {'name': 'Juan', 'gender': 'masculino'},
        ]),
        team('b', 'Amazonas', [
          {'name': 'Maria', 'gender': 'femenino'},
        ]),
      ];
      final matches = [
        finishedMatch(
          events: [goal('home', 'Sin Genero'), goal('home', 'Juan')],
        ),
      ];

      final male = computeHighlightEntries(
        type: TournamentHighlightType.maleScorers,
        registrations: registrations,
        matches: matches,
      );
      final female = computeHighlightEntries(
        type: TournamentHighlightType.femaleScorers,
        registrations: registrations,
        matches: matches,
      );

      expect(male.map((e) => e.name), ['Juan']);
      expect(female.map((e) => e.name), isNot(contains('Sin Genero')));
    });
  });

  group('Bug 2: tocayos en equipos distintos', () {
    test('sus goles no se suman', () {
      final registrations = [
        team('a', 'Halcones', [
          {'name': 'Juan Perez', 'gender': 'masculino'},
        ]),
        team('b', 'Amazonas', [
          {'name': 'Juan Perez', 'gender': 'masculino'},
        ]),
      ];
      final matches = [
        finishedMatch(
          events: [
            goal('home', 'Juan Perez'),
            goal('home', 'Juan Perez'),
            goal('away', 'Juan Perez'),
          ],
        ),
      ];

      final male = computeHighlightEntries(
        type: TournamentHighlightType.maleScorers,
        registrations: registrations,
        matches: matches,
      );

      final byTeam = {for (final e in male) e.team: e.value};
      expect(byTeam['Halcones'], 2);
      expect(byTeam['Amazonas'], 1);
    });

    test('evento sin equipo y jugador en ambas plantillas se omite', () {
      final registrations = [
        team('a', 'Halcones', [
          {'name': 'Juan Perez', 'gender': 'masculino'},
        ]),
        team('b', 'Amazonas', [
          {'name': 'Juan Perez', 'gender': 'masculino'},
        ]),
      ];
      final matches = [
        finishedMatch(
          events: [
            {'type': 'goal', 'playerName': 'Juan Perez', 'player': '7-Juan Perez'},
          ],
        ),
      ];

      final male = computeHighlightEntries(
        type: TournamentHighlightType.maleScorers,
        registrations: registrations,
        matches: matches,
      );

      expect(male.every((e) => e.value == 0), isTrue);
    });
  });

  group('Bug 3: dos porteros en el mismo equipo', () {
    test('ambos quedan en la tabla con los goles del equipo', () {
      final registrations = [
        team('a', 'Halcones', [
          {'name': 'Portero Uno', 'position': 'Portero', 'gender': 'masculino'},
          {'name': 'Portero Dos', 'position': 'Arquero', 'gender': 'masculino'},
        ]),
        team('b', 'Amazonas', [
          {'name': 'Portera', 'position': 'Portera', 'gender': 'femenino'},
        ]),
      ];
      // Halcones (local) recibe 3 goles; Amazonas recibe 1.
      final matches = [finishedMatch(events: const [], home: 1, away: 3)];

      final rows = computeHighlightEntries(
        type: TournamentHighlightType.goalkeepers,
        registrations: registrations,
        matches: matches,
      );

      final received = {for (final e in rows) e.name: e.value};
      expect(received['Portero Uno'], 3);
      expect(received['Portero Dos'], 3);
      expect(received['Portera'], 1);
      // Menos goles recibidos primero.
      expect(rows.first.name, 'Portera');
    });
  });

  test('ignora equipos sin inscripción aprobada y partidos sin planilla', () {
    final registrations = [
      (
        id: 'a',
        data: {
          'teamName': 'Pendiente',
          'status': 'pending',
          'players': [
            {'name': 'Fantasma', 'gender': 'masculino'},
          ],
        },
      ),
    ];
    final matches = [
      finishedMatch(events: [goal('home', 'Fantasma')]),
    ];

    final male = computeHighlightEntries(
      type: TournamentHighlightType.maleScorers,
      registrations: registrations,
      matches: matches,
    );

    expect(male, isEmpty);
  });
}
