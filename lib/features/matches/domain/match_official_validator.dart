/// ES: Valida que los oficiales no participen como jugadores de los equipos.
/// EN: Ensures match officials are not rostered as players on either team.
class MatchOfficialValidator {
  /// ES: Crea un validador sin dependencias externas.
  /// EN: Creates a validator with no external dependencies.
  const MatchOfficialValidator();

  /// ES: Devuelve un mensaje si un árbitro también está en la plantilla.
  /// EN: Returns a message if a referee is also on either team roster.
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
