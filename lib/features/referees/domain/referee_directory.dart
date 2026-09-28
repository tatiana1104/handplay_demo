import 'package:cloud_firestore/cloud_firestore.dart';

/// Un árbitro único, aunque exista en varios documentos de `users`
/// (p. ej. la cuenta de login y el registro creado desde el panel de árbitros).
class RefereeOption {
  final String id;
  final String name;
  final String? email;
  final Set<String> aliasIds;

  const RefereeOption({required this.id, required this.name, required this.email, required this.aliasIds});
}

class RefereeDirectory {
  final List<RefereeOption> options;

  RefereeDirectory._(this.options);

  factory RefereeDirectory.fromDocs(Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final groups = <List<QueryDocumentSnapshot<Map<String, dynamic>>>>[];
    final groupKeys = <Set<String>>[];

    for (final doc in docs) {
      final keys = _identityKeys(doc);
      final matching = <int>[
        for (var i = 0; i < groupKeys.length; i++)
          if (groupKeys[i].intersection(keys).isNotEmpty) i,
      ];
      if (matching.isEmpty) {
        groups.add([doc]);
        groupKeys.add(keys);
        continue;
      }
      final target = matching.first;
      groups[target].add(doc);
      groupKeys[target].addAll(keys);
      for (final index in matching.skip(1).toList().reversed) {
        groups[target].addAll(groups.removeAt(index));
        groupKeys[target].addAll(groupKeys.removeAt(index));
      }
    }

    final options = groups.map((group) {
      group.sort(_preferAuthAccount);
      final primary = group.first;
      final data = primary.data();
      final name = _firstNonEmpty(group.map((doc) => doc.data()['displayName'] ?? doc.data()['nombre'])) ?? 'Árbitro';
      final email = _firstNonEmpty(group.map((doc) => doc.data()['email'] ?? doc.data()['correo']))?.toLowerCase();
      return RefereeOption(
        id: primary.id,
        name: name,
        email: email ?? data['email']?.toString(),
        aliasIds: {
          for (final doc in group) doc.id,
          for (final doc in group)
            if ((doc.data()['uid'] ?? '').toString().isNotEmpty) doc.data()['uid'].toString(),
        },
      );
    }).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return RefereeDirectory._(options);
  }

  RefereeOption? find(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final option in options) {
      if (option.id == id || option.aliasIds.contains(id)) return option;
    }
    return null;
  }

  /// Devuelve el id canónico que se muestra en el desplegable.
  String? canonicalId(String? id) => find(id)?.id;

  static Set<String> _identityKeys(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final document = (data['document'] ?? data['documentNumber'] ?? '').toString().trim();
    final email = (data['email'] ?? data['correo'] ?? '').toString().trim().toLowerCase();
    final uid = (data['uid'] ?? '').toString().trim();
    return {
      'id:${doc.id}',
      if (uid.isNotEmpty) 'id:$uid',
      if (document.isNotEmpty) 'document:$document',
      if (email.isNotEmpty) 'email:$email',
    };
  }

  /// La cuenta de login la crea el flujo de autenticación con `createdAt`;
  /// el registro manual de árbitros no lo escribe.
  static int _preferAuthAccount(
    QueryDocumentSnapshot<Map<String, dynamic>> a,
    QueryDocumentSnapshot<Map<String, dynamic>> b,
  ) {
    final aAuth = a.data()['createdAt'] != null ? 1 : 0;
    final bAuth = b.data()['createdAt'] != null ? 1 : 0;
    if (aAuth != bAuth) return bAuth - aAuth;
    final byCompleteness = _completeness(b.data()) - _completeness(a.data());
    if (byCompleteness != 0) return byCompleteness;
    return a.id.compareTo(b.id);
  }

  static int _completeness(Map<String, dynamic> data) => [
        data['displayName'], data['document'], data['documentNumber'], data['email'],
        data['phone'], data['accreditation'], data['category'],
      ].where((value) => value != null && value.toString().trim().isNotEmpty).length;

  static String? _firstNonEmpty(Iterable<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return null;
  }
}
