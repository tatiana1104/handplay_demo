import 'package:cloud_firestore/cloud_firestore.dart';

/// Torneo principal administrado por una liga.
class Tournament {
  /// ES: Crea el modelo de dominio de un torneo.
  /// EN: Creates a tournament domain model.
  const Tournament({
    required this.id,
    required this.adminId,
    required this.name,
    required this.status,
    required this.startDate,
    required this.endDate,
    required this.format,
    required this.categories,
    required this.teamLimit,
    required this.minPlayersPerTeam,
    required this.maxPlayersPerTeam,
    required this.publicRegistration,
    required this.registrationDeadline,
    required this.phaseDurations,
  });

  final String id;
  final String adminId;
  final String name;
  final String status;
  final DateTime? startDate;
  final DateTime? endDate;
  final String format;
  /// Categorías seleccionadas como pares `categoria|rama`.
  final List<String> categories;
  final int teamLimit;
  final int minPlayersPerTeam;
  final int maxPlayersPerTeam;
  final bool publicRegistration;
  final DateTime? registrationDeadline;
  final Map<String, int> phaseDurations;

  /// ES: Une y normaliza categorías para comprobar las ramas.
  /// EN: Joins and normalizes categories for branch checks.
  String _normalizedCategories() => categories.join(' ').trim().toLowerCase();

  /// ES: Indica una rama mixta o categorías para ambas ramas de género.
  /// EN: Indicates a mixed branch or categories for both gender branches.
  bool get isMixedTournament {
    final value = _normalizedCategories();
    return value.contains('mixt') || (hasMaleCategory && hasFemaleCategory);
  }

  /// ES: Comprueba si las categorías incluyen la rama masculina.
  /// EN: Checks whether the configured categories include a male branch.
  bool get hasMaleCategory {
    final value = _normalizedCategories();
    return value.contains('masc') || value.contains('hombre') || value.contains('male');
  }

  /// ES: Comprueba si las categorías incluyen la rama femenina.
  /// EN: Checks whether the configured categories include a female branch.
  bool get hasFemaleCategory {
    final value = _normalizedCategories();
    return value.contains('fem') || value.contains('mujer') || value.contains('female');
  }

  /// ES: Determina si deben mostrarse las estadísticas de goleadores.
  /// EN: Determines whether male scorer statistics should be shown.
  bool get shouldShowMaleScorers => hasMaleCategory || isMixedTournament;

  /// ES: Determina si deben mostrarse las estadísticas de goleadoras.
  /// EN: Determines whether female scorer statistics should be shown.
  bool get shouldShowFemaleScorers => hasFemaleCategory || isMixedTournament;

  /// Estado visible para la liga: la fecha de inicio activa el torneo,
  /// salvo que el administrador lo haya marcado explícitamente como finalizado.
  String get effectiveStatus {
    final normalized = status.trim().toLowerCase();
    final isFinished = normalized == 'finished' || normalized == 'finalized' || normalized == 'finalizado' || normalized == 'finalizada';
    if (isFinished) return 'Finalizado';
    if (startDate != null && !DateTime.now().isBefore(startDate!)) return 'En curso';
    if (normalized == 'active' || normalized == 'playing' || normalized == 'jugando' || normalized == 'en_curso') return 'En curso';
    return 'Por iniciar';
  }

  /// ES: Crea el modelo de dominio desde un documento de torneo.
  /// EN: Builds a domain model from a tournament document.
  factory Tournament.fromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return Tournament(
      id: doc.id,
      adminId: data['adminId'] as String? ?? '',
      name: data['name'] as String? ?? '',
      status: data['status'] as String? ?? 'draft',
      startDate: _date(data['startDate']),
      endDate: _date(data['endDate']),
      format: data['format'] as String? ?? '',
      categories: (data['categories'] as List<dynamic>? ?? const []).cast<String>(),
      teamLimit: (data['teamLimit'] as num?)?.toInt() ?? 0,
      minPlayersPerTeam: (data['minPlayersPerTeam'] as num?)?.toInt() ?? 1,
      maxPlayersPerTeam: (data['maxPlayersPerTeam'] as num?)?.toInt() ?? 99,
      publicRegistration: data['publicRegistration'] as bool? ?? false,
      registrationDeadline: _date(data['registrationDeadline']),
      phaseDurations: _intMap(data['phaseDurations']),
    );
  }

  /// ES: Serializa los campos del torneo para guardarlos en Firestore.
  /// EN: Serializes tournament fields for a Firestore write.
  Map<String, dynamic> toFirestore() => {
        'adminId': adminId,
        'name': name,
        'status': status,
        'startDate': _timestamp(startDate),
        'endDate': _timestamp(endDate),
        'format': format,
        'categories': categories,
        'teamLimit': teamLimit,
        'minPlayersPerTeam': minPlayersPerTeam,
        'maxPlayersPerTeam': maxPlayersPerTeam,
        'publicRegistration': publicRegistration,
        'registrationDeadline': _timestamp(registrationDeadline),
        'phaseDurations': phaseDurations,
        'updatedAt': FieldValue.serverTimestamp(),
      };
}

/// Categoría competitiva perteneciente a un torneo.
class TournamentCategory {
  /// ES: Crea una categoría competitiva perteneciente a un torneo.
  /// EN: Creates a competition category belonging to a tournament.
  const TournamentCategory({required this.id, required this.tournamentId, required this.name, required this.baseCategory, required this.modality, required this.minimumGenderQuota});
  final String id;
  final String tournamentId;
  final String name;
  final String baseCategory;
  final String modality;
  final int minimumGenderQuota;

  /// ES: Crea el modelo de categoría desde un documento Firestore.
  /// EN: Builds a category model from a Firestore document.
  factory TournamentCategory.fromDocument(DocumentSnapshot<Map<String, dynamic>> doc, String tournamentId) {
    final data = doc.data() ?? const <String, dynamic>{};
    return TournamentCategory(id: doc.id, tournamentId: tournamentId, name: data['name'] as String? ?? '', baseCategory: data['baseCategory'] as String? ?? '', modality: data['modality'] as String? ?? '', minimumGenderQuota: (data['minimumGenderQuota'] as num?)?.toInt() ?? 0);
  }
}

/// Sede donde se disputan los partidos del torneo.
class TournamentVenue {
  /// ES: Crea una sede perteneciente a un torneo.
  /// EN: Creates a venue belonging to a tournament.
  const TournamentVenue({required this.id, required this.tournamentId, required this.name, required this.address});
  final String id;
  final String tournamentId;
  final String name;
  final String address;

  /// ES: Crea el modelo de sede desde un documento Firestore.
  /// EN: Builds a venue model from a Firestore document.
  factory TournamentVenue.fromDocument(DocumentSnapshot<Map<String, dynamic>> doc, String tournamentId) {
    final data = doc.data() ?? const <String, dynamic>{};
    return TournamentVenue(id: doc.id, tournamentId: tournamentId, name: data['name'] as String? ?? '', address: data['address'] as String? ?? '');
  }
}

/// ES: Convierte timestamps Firestore o fechas a una fecha Dart opcional.
/// EN: Converts Firestore timestamps or dates to a nullable Dart date.
DateTime? _date(Object? value) => value is Timestamp ? value.toDate() : value is DateTime ? value : null;

/// ES: Convierte una fecha Dart opcional en un timestamp Firestore.
/// EN: Converts a nullable Dart date to a Firestore timestamp.
Object? _timestamp(DateTime? value) => value == null ? null : Timestamp.fromDate(value);

/// ES: Lee duraciones enteras de fases desde un mapa Firestore.
/// EN: Reads integer-valued phase durations from Firestore map data.
Map<String, int> _intMap(Object? value) => value is Map ? value.map((key, item) => MapEntry(key.toString(), (item as num).toInt())) : <String, int>{};
