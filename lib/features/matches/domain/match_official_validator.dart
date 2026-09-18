class MatchOfficialValidator {
  const MatchOfficialValidator();

  String? findTeamConflict({
    required Iterable<String> refereeIds,
    required Iterable<String> homePlayerIds,
    required Iterable<String> awayPlayerIds,
    required String homeTeamName,
    required String awayTeamName,
  }) {
    final playersByTeam = <String, String>{
      for (final id in homePlayerIds) id: homeTeamName,
      for (final id in awayPlayerIds) id: awayTeamName,
    };

    for (final refereeId in refereeIds) {
      final teamName = playersByTeam[refereeId];
      if (teamName != null) {
        return '$refereeId también está inscrito como jugador en $teamName. No puede ser asignado a un partido de su propio equipo.';
      }
    }
    return null;
  }
}
