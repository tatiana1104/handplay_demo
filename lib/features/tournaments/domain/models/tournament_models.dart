import 'package:cloud_firestore/cloud_firestore.dart';

/// Torneo principal administrado por una liga.
class Tournament {
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
  final bool publicRegistration;
  final DateTime? registrationDeadline;
  final Map<String, int> phaseDurations;

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
      publicRegistration: data['publicRegistration'] as bool? ?? false,
      registrationDeadline: _date(data['registrationDeadline']),
      phaseDurations: _intMap(data['phaseDurations']),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'adminId': adminId,
        'name': name,
        'status': status,
        'startDate': _timestamp(startDate),
        'endDate': _timestamp(endDate),
        'format': format,
        'categories': categories,
        'teamLimit': teamLimit,
        'publicRegistration': publicRegistration,
        'registrationDeadline': _timestamp(registrationDeadline),
        'phaseDurations': phaseDurations,
        'updatedAt': FieldValue.serverTimestamp(),
      };
}

/// Categoría competitiva perteneciente a un torneo.
class TournamentCategory {
  const TournamentCategory({required this.id, required this.tournamentId, required this.name, required this.baseCategory, required this.modality, required this.minimumGenderQuota});
  final String id;
  final String tournamentId;
  final String name;
  final String baseCategory;
  final String modality;
  final int minimumGenderQuota;

  factory TournamentCategory.fromDocument(DocumentSnapshot<Map<String, dynamic>> doc, String tournamentId) {
    final data = doc.data() ?? const <String, dynamic>{};
    return TournamentCategory(id: doc.id, tournamentId: tournamentId, name: data['name'] as String? ?? '', baseCategory: data['baseCategory'] as String? ?? '', modality: data['modality'] as String? ?? '', minimumGenderQuota: (data['minimumGenderQuota'] as num?)?.toInt() ?? 0);
  }
}

/// Sede donde se disputan los partidos del torneo.
class TournamentVenue {
  const TournamentVenue({required this.id, required this.tournamentId, required this.name, required this.address});
  final String id;
  final String tournamentId;
  final String name;
  final String address;

  factory TournamentVenue.fromDocument(DocumentSnapshot<Map<String, dynamic>> doc, String tournamentId) {
    final data = doc.data() ?? const <String, dynamic>{};
    return TournamentVenue(id: doc.id, tournamentId: tournamentId, name: data['name'] as String? ?? '', address: data['address'] as String? ?? '');
  }
}

DateTime? _date(Object? value) => value is Timestamp ? value.toDate() : value is DateTime ? value : null;
Object? _timestamp(DateTime? value) => value == null ? null : Timestamp.fromDate(value);
Map<String, int> _intMap(Object? value) => value is Map ? value.map((key, item) => MapEntry(key.toString(), (item as num).toInt())) : <String, int>{};
