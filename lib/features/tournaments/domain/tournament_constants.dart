/// Valores cerrados del dominio de torneos. No deben escribirse como texto libre.
abstract final class TournamentConstants {
  static const categories = <String>[
    'master',
    'mayor',
    'juvenil',
    'cadete',
    'infantil',
    'libre',
  ];

  static const branches = <String>['femenino', 'masculino', 'mixto'];
  static const formats = <String>['todos_contra_todos', 'por_grupos'];
  static const roles = <String>['admin', 'admin_liga', 'jugador', 'entrenador', 'arbitro'];
  static const statuses = <String>['draft', 'upcoming', 'playing', 'finished'];
}

String titleCase(String value) => value
    .split('_')
    .map((part) => part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}')
    .join(' ');
