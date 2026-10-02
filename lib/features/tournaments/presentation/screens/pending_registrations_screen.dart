import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// ES: Permite revisar y decidir sobre las inscripciones de un torneo.
/// EN: Lets administrators review and decide tournament registrations.
class PendingRegistrationsScreen extends StatefulWidget {
  /// ES: Crea la pantalla para las solicitudes del torneo indicado.
  /// EN: Creates the registration review screen for the specified tournament.
  const PendingRegistrationsScreen({
    super.key,
    required this.tournamentId,
    required this.tournamentName,
  });

  final String tournamentId;
  final String tournamentName;

  /// ES: Crea el estado que administra filtro y decisiones de revisión.
  /// EN: Creates the state that manages review filters and decisions.
  @override
  State<PendingRegistrationsScreen> createState() =>
      _PendingRegistrationsScreenState();
}

class _PendingRegistrationsScreenState
    extends State<PendingRegistrationsScreen> {
  String _selectedStatus = 'pending';

  /// ES: Devuelve la subcolección de inscripciones del torneo actual.
  /// EN: Returns the current tournament's registrations subcollection.
  CollectionReference<Map<String, dynamic>> get _registrations =>
      FirebaseFirestore.instance
          .collection('tournaments')
          .doc(widget.tournamentId)
          .collection('registrations');

  /// ES: Aprueba o rechaza una solicitud y sincroniza sus perfiles relacionados.
  /// EN: Approves or rejects a request and syncs its related profiles.
  Future<void> _setStatus(
    BuildContext context,
    String id,
    String status,
  ) async {
    String? rejectionReason;
    final currentSnapshot = await _registrations.doc(id).get();
    final current = currentSnapshot.data() ?? <String, dynamic>{};
    if (status == 'rejected') {
      final allRegistrations = await _registrations.get();
      final currentCreatedAt = current['createdAt'];
      final currentDate = currentCreatedAt is Timestamp
          ? currentCreatedAt.toDate()
          : DateTime.now();
      final older = allRegistrations.docs
          .where((doc) => doc.id != id && _createdAt(doc).isBefore(currentDate))
          .toList();
      final warnings = _similarityWarnings(current, older);
      final suggestedReason = warnings.isEmpty
          ? 'Revisa los datos de la inscripción antes de volver a enviarla.'
          : 'Advertencia de similitud:\n${warnings.join('\n')}';
      final controller = TextEditingController(text: suggestedReason);
      rejectionReason = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Datos por corregir'),
          content: TextField(
            controller: controller,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: 'Información para el entrenador',
              hintText:
                  'Indica qué debe cambiar antes de reenviar la inscripción.',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, controller.text.trim()),
              child: const Text('Rechazar'),
            ),
          ],
        ),
      );
      controller.dispose();
      if (rejectionReason == null || rejectionReason!.isEmpty) return;
    }
    final registrationRef = _registrations.doc(id);
    final batch = FirebaseFirestore.instance.batch();
    batch.update(registrationRef, {
      'status': status,
      'reviewedAt': FieldValue.serverTimestamp(),
      if (status == 'rejected') 'rejectionReason': rejectionReason,
      if (status == 'approved') 'rejectionReason': FieldValue.delete(),
    });
    final teamRef = FirebaseFirestore.instance
        .collection('tournaments')
        .doc(widget.tournamentId)
        .collection('teams')
        .doc(id);
    batch.set(teamRef, {
      'registrationId': id,
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    if (status == 'approved') {
      final currentPlayers =
          (current['players'] as List?)
              ?.whereType<Map>()
              .map((player) => Map<String, dynamic>.from(player))
              .toList() ??
          const <Map<String, dynamic>>[];
      final profiles = FirebaseFirestore.instance.collection(
        'profile_directory',
      );
      final users = FirebaseFirestore.instance.collection('users');
      final coachDocument = current['coachDocument']?.toString().trim() ?? '';
      final clubEmail =
          current['clubEmail']?.toString().trim().toLowerCase() ?? '';
      final coachMatches = await profiles
          .where('document', isEqualTo: coachDocument)
          .limit(1)
          .get();
      final coachRef = coachMatches.docs.isEmpty
          ? profiles.doc('document_$coachDocument')
          : coachMatches.docs.first.reference;
      batch.set(coachRef, {
        'roles': FieldValue.arrayUnion(['entrenador']),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      for (final player in currentPlayers) {
        final document = player['document']?.toString().trim() ?? '';
        if (document.isEmpty) continue;
        final playerMatches = await profiles
            .where('document', isEqualTo: document)
            .limit(1)
            .get();
        final playerRef = playerMatches.docs.isEmpty
            ? profiles.doc('document_$document')
            : playerMatches.docs.first.reference;
        batch.set(playerRef, {
          'roles': FieldValue.arrayUnion(['jugador']),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        final playerUsers = await users
            .where('document', isEqualTo: document)
            .limit(1)
            .get();
        final playerUsersByNumber = playerUsers.docs.isEmpty
            ? await users
                  .where('documentNumber', isEqualTo: document)
                  .limit(1)
                  .get()
            : playerUsers;
        if (playerUsersByNumber.docs.isNotEmpty) {
          batch.set(playerUsersByNumber.docs.first.reference, {
            'roles': FieldValue.arrayUnion(['jugador']),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      }
    }
    await batch.commit();
    if (context.mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == 'approved'
                ? 'Solicitud aprobada.'
                : 'Solicitud rechazada.',
          ),
        ),
      );
  }

  /// ES: Lee la fecha de creación y usa el inicio de época si falta.
  /// EN: Reads the creation date, defaulting to the Unix epoch when absent.
  DateTime _createdAt(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final value = doc.data()['createdAt'];
    return value is Timestamp
        ? value.toDate()
        : DateTime.fromMillisecondsSinceEpoch(0);
  }

  /// ES: Compara una solicitud con las anteriores y resume posibles similitudes.
  /// EN: Compares a request with earlier ones and reports possible similarities.
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
      if (_normalize(previous['category']) != _normalize(current['category']))
        continue;
      final previousName = _normalize(previous['teamName']);
      final previousColor = _normalize(previous['uniformColor']);
      final previousPlayers = _playerKeys(previous['players']);
      final label = previous['teamName'] as String? ?? 'otro equipo';
      if (currentName.isNotEmpty && currentName == previousName)
        warnings.add('Mismo nombre de equipo que "$label".');
      if (currentColor.isNotEmpty && currentColor == previousColor)
        warnings.add('Mismo color de uniforme que "$label".');
      final repeatedPlayers = currentPlayers.intersection(previousPlayers);
      if (repeatedPlayers.isNotEmpty) {
        final currentPlayerDetails = _playerDetails(current['players']);
        final previousPlayerDetails = _playerDetails(previous['players']);
        final details = repeatedPlayers
            .map((key) {
              final player =
                  currentPlayerDetails[key] ?? previousPlayerDetails[key];
              return player == null
                  ? key
                  : '${player['name']} — documento: ${player['document']}';
            })
            .join('; ');
        warnings.add('Jugadores con similitud en "$label": $details.');
      }
    }
    return warnings.toList();
  }

  /// ES: Normaliza un valor para comparar nombres y documentos.
  /// EN: Normalizes a value for comparing names and identity documents.
  String _normalize(Object? value) =>
      value?.toString().trim().toLowerCase() ?? '';

  /// ES: Obtiene claves estables para identificar los jugadores de una solicitud.
  /// EN: Gets stable keys for identifying a request's players.
  Set<String> _playerKeys(Object? value) => _playerDetails(value).keys.toSet();

  /// ES: Organiza nombres y documentos de jugadores por su clave normalizada.
  /// EN: Indexes player names and documents by their normalized key.
  Map<String, Map<String, String>> _playerDetails(Object? value) {
    final players = value is List ? value : const <dynamic>[];
    final details = <String, Map<String, String>>{};
    for (final player in players) {
      if (player is! Map) continue;
      final document = player['document']?.toString().trim() ?? '';
      final name = player['name']?.toString().trim() ?? '';
      final key = _normalize(document.isNotEmpty ? document : name);
      if (key.isNotEmpty) {
        details[key] = {
          'name': name.isNotEmpty ? name : 'Nombre no registrado',
          'document': document.isNotEmpty
              ? document
              : 'Documento no registrado',
        };
      }
    }
    return details;
  }

  /// ES: Muestra solicitudes en tiempo real y permite filtrarlas por estado.
  /// EN: Displays live registration requests and filters them by status.
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Solicitudes pendientes')),
    body: SafeArea(
      bottom: true,
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _registrations
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return Center(
              child: Text('No se pudieron cargar las solicitudes.'),
            );
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;
          final pending = docs
              .where((doc) => doc.data()['status'] == 'pending')
              .toList();
          final approved = docs
              .where((doc) => doc.data()['status'] == 'approved')
              .toList();
          final rejected = docs
              .where((doc) => doc.data()['status'] == 'rejected')
              .toList();
          final visible = _selectedStatus == 'pending'
              ? pending
              : _selectedStatus == 'approved'
              ? approved
              : rejected;
          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
            children: [
              Text(
                widget.tournamentName,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              _RegistrationFilterBar(
                selected: _selectedStatus,
                counts: {
                  'pending': pending.length,
                  'approved': approved.length,
                  'rejected': rejected.length,
                },
                onChanged: (status) => setState(() => _selectedStatus = status),
              ),
              const SizedBox(height: 12),
              if (visible.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      _selectedStatus == 'pending'
                          ? 'No hay solicitudes pendientes.'
                          : _selectedStatus == 'approved'
                          ? 'No hay solicitudes aprobadas.'
                          : 'No hay solicitudes rechazadas.',
                    ),
                  ),
                ),
              ...visible.asMap().entries.map((entry) {
                final doc = entry.value;
                final data = doc.data();
                final players =
                    (data['players'] as List<dynamic>? ?? const []).length;
                final warnings = _similarityWarnings(
                  data,
                  docs
                      .where(
                        (other) =>
                            other.id != doc.id &&
                            _createdAt(other).isBefore(_createdAt(doc)),
                      )
                      .toList(),
                );
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                data['teamName'] as String? ??
                                    'Equipo sin nombre',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            Chip(
                              label: Text(
                                data['status'] == 'approved'
                                    ? 'aprobada'
                                    : data['status'] == 'rejected'
                                    ? 'rechazada'
                                    : 'pendiente',
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '${data['category'] ?? 'Sin categoría'} · ${data['clubName'] ?? 'Club independiente'}',
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Color: ${data['uniformColor'] ?? 'Sin definir'} · Entrenador: ${data['coachName'] ?? 'Sin definir'}',
                        ),
                        Text(
                          '$players jugadores registrados · ${data['clubEmail'] ?? ''}',
                        ),
                        if (warnings.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .errorContainer
                                  .withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onErrorContainer,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Advertencia de similitud:\n${warnings.join('\\n')}',
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onErrorContainer,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => _RegistrationDetailScreen(
                                  tournamentName: widget.tournamentName,
                                  registration: data,
                                ),
                              ),
                            ),
                            icon: const Icon(Icons.article_outlined),
                            label: const Text('Ver inscripción completa'),
                          ),
                        ),
                        if (_selectedStatus == 'pending')
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: () =>
                                      _setStatus(context, doc.id, 'approved'),
                                  icon: const Icon(Icons.check),
                                  label: const Text('Aprobar'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () =>
                                      _setStatus(context, doc.id, 'rejected'),
                                  icon: const Icon(Icons.close),
                                  label: const Text('Rechazar'),
                                ),
                              ),
                            ],
                          )
                        else
                          Text(
                            _selectedStatus == 'approved'
                                ? 'Solicitud aprobada'
                                : 'Solicitud rechazada',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    ),
  );
}

class _RegistrationFilterBar extends StatelessWidget {
  /// ES: Crea la barra de filtros con conteos por estado.
  /// EN: Creates the filter bar with counts for each status.
  const _RegistrationFilterBar({
    required this.selected,
    required this.counts,
    required this.onChanged,
  });

  final String selected;
  final Map<String, int> counts;
  final ValueChanged<String> onChanged;

  /// ES: Construye los filtros horizontales de estado.
  /// EN: Builds the horizontal status filters.
  @override
  Widget build(BuildContext context) {
    const filters = [
      ('pending', 'Pendientes'),
      ('approved', 'Aprobadas'),
      ('rejected', 'Rechazadas'),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          for (final filter in filters) ...[
            _RegistrationFilterChip(
              label: '${filter.$2} (${counts[filter.$1] ?? 0})',
              selected: selected == filter.$1,
              onTap: () => onChanged(filter.$1),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _RegistrationFilterChip extends StatelessWidget {
  /// ES: Crea una opción seleccionable de estado.
  /// EN: Creates a selectable registration status option.
  const _RegistrationFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// ES: Dibuja la opción y refleja si está seleccionada.
  /// EN: Renders the option and indicates whether it is selected.
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: selected
            ? colorScheme.primary.withValues(alpha: .22)
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected
              ? colorScheme.primary.withValues(alpha: .45)
              : colorScheme.outlineVariant.withValues(alpha: .5),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            child: Text(
              label,
              style: TextStyle(
                color: selected
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// ES: Presenta todos los datos recibidos en una solicitud de equipo.
/// EN: Displays all details submitted in a team registration.
class _RegistrationDetailScreen extends StatelessWidget {
  /// ES: Crea la ficha completa de una inscripción.
  /// EN: Creates the full registration detail screen.
  const _RegistrationDetailScreen({
    required this.tournamentName,
    required this.registration,
  });

  final String tournamentName;
  final Map<String, dynamic> registration;

  /// ES: Lee un campo de texto y entrega una alternativa cuando está vacío.
  /// EN: Reads a text field and returns a fallback when it is empty.
  String _value(String key, [String fallback = 'No registrado']) {
    final value = registration[key]?.toString().trim();
    return value == null || value.isEmpty ? fallback : value;
  }

  /// ES: Convierte una fecha Firestore en una fecha legible.
  /// EN: Converts a Firestore date into a readable date string.
  String _date(Object? value) {
    final date = value is Timestamp
        ? value.toDate()
        : DateTime.tryParse(value?.toString() ?? '');
    if (date == null) return 'No registrada';
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  /// ES: Construye la ficha con datos generales, entrenador y plantilla.
  /// EN: Builds the detail view with team, coach, and roster information.
  @override
  Widget build(BuildContext context) {
    final players =
        (registration['players'] as List?)
            ?.whereType<Map>()
            .map((player) => Map<String, dynamic>.from(player))
            .toList() ??
        const <Map<String, dynamic>>[];
    final clubs =
        (registration['clubs'] as List?)
            ?.map((club) => club.toString())
            .where((club) => club.trim().isNotEmpty)
            .toList() ??
        const <String>[];
    final status = _value('status', 'pending');

    return Scaffold(
      appBar: AppBar(title: const Text('Inscripción completa')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Text(tournamentName, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            _value('teamName', 'Equipo sin nombre'),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          _detailSection(context, 'Estado y categoría', [
            _detailRow('Estado', status),
            _detailRow('Categoría y rama', _value('category')),
            _detailRow('Color del uniforme', _value('uniformColor')),
            _detailRow('Fecha de solicitud', _date(registration['createdAt'])),
            _detailRow('Fecha de revisión', _date(registration['reviewedAt'])),
            if (_value('rejectionReason', '').isNotEmpty)
              _detailRow('Motivo de rechazo', _value('rejectionReason')),
          ]),
          _detailSection(context, 'Clubes asociados', [
            _detailRow(
              'Clubes',
              clubs.isNotEmpty
                  ? clubs.join(', ')
                  : _value('clubName', 'Club independiente'),
            ),
          ]),
          _detailSection(context, 'Datos del entrenador', [
            _detailRow('Nombre', _value('coachName')),
            _detailRow('Documento', _value('coachDocument')),
            _detailRow('Correo', _value('clubEmail')),
            _detailRow('Teléfono', _value('coachPhone')),
          ]),
          _detailSection(context, 'Plantilla (${players.length})', [
            if (players.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('La solicitud no contiene jugadores.'),
              )
            else
              for (var index = 0; index < players.length; index++) ...[
                if (index > 0) const Divider(height: 16),
                _playerDetail(context, players[index], index + 1),
              ],
          ]),
          if (_value('verificationMessage', '').isNotEmpty)
            _detailSection(context, 'Observaciones', [
              _detailRow('Mensaje', _value('verificationMessage')),
            ]),
        ],
      ),
    );
  }

  /// ES: Agrupa filas relacionadas dentro de una sección visual.
  /// EN: Groups related detail rows into a visual section.
  Widget _detailSection(
    BuildContext context,
    String title,
    List<Widget> children,
  ) => Card(
    margin: const EdgeInsets.only(top: 10),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    ),
  );

  /// ES: Muestra una propiedad de la inscripción con su valor.
  /// EN: Displays one registration property with its value.
  Widget _detailRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 132, child: Text(label)),
        const SizedBox(width: 8),
        Expanded(child: Text(value)),
      ],
    ),
  );

  /// ES: Presenta los datos deportivos y de identidad de un jugador.
  /// EN: Displays a player's sports and identity details.
  Widget _playerDetail(
    BuildContext context,
    Map<String, dynamic> player,
    int number,
  ) {
    final playerName = player['name']?.toString().trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$number. ${playerName?.isNotEmpty == true ? playerName : 'Jugador sin nombre'}',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        _detailRow(
          'Documento',
          player['document']?.toString() ?? 'No registrado',
        ),
        _detailRow('Dorsal', player['number']?.toString() ?? 'No registrado'),
        _detailRow(
          'Posición',
          player['position']?.toString() ?? 'No registrada',
        ),
        _detailRow('Género', player['gender']?.toString() ?? 'No registrado'),
        _detailRow('Club', player['club']?.toString() ?? 'Sin club'),
      ],
    );
  }
}
