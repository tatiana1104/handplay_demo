import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class PendingRegistrationsScreen extends StatefulWidget {
  const PendingRegistrationsScreen({super.key, required this.tournamentId, required this.tournamentName});

  @override
  State<PendingRegistrationsScreen> createState() => _PendingRegistrationsScreenState();
}

class _PendingRegistrationsScreenState extends State<PendingRegistrationsScreen> {
  final String tournamentId;
  final String tournamentName;
  String _selectedStatus = 'pending';

  CollectionReference<Map<String, dynamic>> get _registrations => FirebaseFirestore.instance.collection('tournaments').doc(widget.tournamentId).collection('registrations');

  Future<void> _setStatus(BuildContext context, String id, String status) async {
    await _registrations.doc(id).update({'status': status, 'reviewedAt': FieldValue.serverTimestamp()});
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(status == 'approved' ? 'Solicitud aprobada.' : 'Solicitud rechazada.')));
  }

  DateTime _createdAt(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final value = doc.data()['createdAt'];
    return value is Timestamp ? value.toDate() : DateTime.fromMillisecondsSinceEpoch(0);
  }

  List<String> _similarityWarnings(
    Map<String, dynamic> current,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> olderRegistrations,
  ) {
    final warnings = <String>{};
    final currentName = _normalize(current['teamName']);
    final currentColor = _normalize(current['uniformColor']);
    final currentPlayers = _playerKeys(current['players']);

    for (final older in olderRegistrations) {
      final previous = older.data();
      if (_normalize(previous['category']) != _normalize(current['category'])) continue;
      final previousName = _normalize(previous['teamName']);
      final previousColor = _normalize(previous['uniformColor']);
      final previousPlayers = _playerKeys(previous['players']);
      final label = previous['teamName'] as String? ?? 'otro equipo';
      if (currentName.isNotEmpty && currentName == previousName) warnings.add('Mismo nombre de equipo que "$label".');
      if (currentColor.isNotEmpty && currentColor == previousColor) warnings.add('Mismo color de uniforme que "$label".');
      final repeatedPlayers = currentPlayers.intersection(previousPlayers);
      if (repeatedPlayers.isNotEmpty) warnings.add('${repeatedPlayers.length} jugador(es) también aparece(n) en "$label".');
    }
    return warnings.toList();
  }

  String _normalize(Object? value) => value?.toString().trim().toLowerCase() ?? '';

  Set<String> _playerKeys(Object? value) {
    final players = value is List ? value : const <dynamic>[];
    return players.map((player) {
      if (player is Map) {
        final document = _normalize(player['document']);
        return document.isNotEmpty ? document : _normalize(player['name']);
      }
      return '';
    }).where((key) => key.isNotEmpty).toSet();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Solicitudes pendientes')),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _registrations.orderBy('createdAt', descending: true).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) return Center(child: Text('No se pudieron cargar las solicitudes.'));
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final docs = snapshot.data!.docs;
            final pending = docs.where((doc) => doc.data()['status'] == 'pending').toList();
            final approved = docs.where((doc) => doc.data()['status'] == 'approved').toList();
            final rejected = docs.where((doc) => doc.data()['status'] == 'rejected').toList();
            final visible = _selectedStatus == 'pending' ? pending : _selectedStatus == 'approved' ? approved : rejected;
            return ListView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
              children: [
                Text(widget.tournamentName, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: [
                    ButtonSegment(value: 'pending', label: Text('Pendientes (${pending.length})')),
                    ButtonSegment(value: 'approved', label: Text('Aprobadas (${approved.length})')),
                    ButtonSegment(value: 'rejected', label: Text('Rechazadas (${rejected.length})')),
                  ],
                  selected: {_selectedStatus},
                  onSelectionChanged: (selection) => setState(() => _selectedStatus = selection.first),
                ),
                const SizedBox(height: 12),
                if (visible.isEmpty) Card(child: Padding(padding: const EdgeInsets.all(20), child: Text(_selectedStatus == 'pending' ? 'No hay solicitudes pendientes.' : _selectedStatus == 'approved' ? 'No hay solicitudes aprobadas.' : 'No hay solicitudes rechazadas.'))),
                ...visible.asMap().entries.map((entry) {
                  final doc = entry.value;
                  final data = doc.data();
                  final players = (data['players'] as List<dynamic>? ?? const []).length;
                  final warnings = _similarityWarnings(data, docs.where((other) => other.id != doc.id && _createdAt(other) < _createdAt(doc)).toList());
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [Expanded(child: Text(data['teamName'] as String? ?? 'Equipo sin nombre', style: Theme.of(context).textTheme.titleMedium)), Chip(label: const Text('pendiente'))]),
                        Text('${data['category'] ?? 'Sin categoría'} · ${data['clubName'] ?? 'Club independiente'}'),
                        const SizedBox(height: 6),
                        Text('Color: ${data['uniformColor'] ?? 'Sin definir'} · Entrenador: ${data['coachName'] ?? 'Sin definir'}'),
                        Text('$players jugadores registrados · ${data['coachEmail'] ?? ''}'),
                        if (warnings.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.warning_amber_rounded, color: Theme.of(context).colorScheme.onErrorContainer),
                                const SizedBox(width: 8),
                                Expanded(child: Text('Advertencia de similitud:\n${warnings.join('\\n')}', style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer))),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        if (_selectedStatus == 'pending')
                          Row(children: [Expanded(child: FilledButton.icon(onPressed: () => _setStatus(context, doc.id, 'approved'), icon: const Icon(Icons.check), label: const Text('Aprobar'))), const SizedBox(width: 8), Expanded(child: OutlinedButton.icon(onPressed: () => _setStatus(context, doc.id, 'rejected'), icon: const Icon(Icons.close), label: const Text('Rechazar')))])
                        else
                          Text(_selectedStatus == 'approved' ? 'Solicitud aprobada' : 'Solicitud rechazada', style: Theme.of(context).textTheme.labelLarge),
                      ]),
                    ),
                  );
                }),
              ],
            );
          },
        ),
      );
}
