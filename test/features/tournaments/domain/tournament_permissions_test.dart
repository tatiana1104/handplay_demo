import 'package:flutter_test/flutter_test.dart';
import 'package:handplay_demo/features/tournaments/domain/tournament_permissions.dart';

void main() {
  test('recognizes administrator among multiple custom-claim roles', () {
    expect(
      hasTournamentAdminRole(
        claims: {
          'roles': ['jugador', 'admin_liga', 'arbitro'],
        },
      ),
      isTrue,
    );
  });

  test('recognizes legacy administrator claims and normalized role names', () {
    expect(hasTournamentAdminRole(claims: {'rol': 'admin'}), isTrue);
    expect(hasTournamentAdminRole(roles: ['Admin Liga']), isTrue);
  });

  test('does not authorize non-administrator roles', () {
    expect(
      hasTournamentAdminRole(
        claims: {
          'roles': ['jugador', 'entrenador', 'arbitro'],
          'rol': 'entrenador',
        },
      ),
      isFalse,
    );
  });
}
