const _tournamentAdminRoles = {'admin', 'admin_liga'};

bool hasTournamentAdminRole({
  Iterable<String> roles = const [],
  Map<String, dynamic>? claims,
}) {
  final claimRoles = claims?['roles'];
  final allRoles = <String>[
    ...roles,
    if (claimRoles is List) ...claimRoles.whereType<String>(),
  ];
  final legacyRole = claims?['rol'];
  if (legacyRole is String) allRoles.add(legacyRole);

  return allRoles.any((role) {
    final normalized = role.trim().toLowerCase().replaceAll(' ', '_');
    return _tournamentAdminRoles.contains(normalized);
  });
}
