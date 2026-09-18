import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../domain/models/tournament_models.dart';

/// Solicitud pública para inscribir un equipo y sus jugadores.
class TeamRegistrationScreen extends StatefulWidget {
  const TeamRegistrationScreen({required this.tournament, this.initialRegistration, this.registrationId, this.rejectionReason, super.key});
  final Tournament tournament;
  final Map<String, dynamic>? initialRegistration;
  final String? registrationId;
  final String? rejectionReason;

  @override
  State<TeamRegistrationScreen> createState() => _TeamRegistrationScreenState();
}

class _PlayerDialog extends StatefulWidget {
  const _PlayerDialog({required this.usedNumbers, required this.tournamentBranch});

  final Set<int> usedNumbers;
  final String tournamentBranch;

  @override
  State<_PlayerDialog> createState() => _PlayerDialogState();
}

class _PlayerDialogState extends State<_PlayerDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _document = TextEditingController();
  final _number = TextEditingController();
  final _position = TextEditingController();
  final _club = TextEditingController();
  String? _gender;

  @override
  void dispose() {
    _name.dispose();
    _document.dispose();
    _number.dispose();
    _position.dispose();
    _club.dispose();
    super.dispose();
  }

  static const positions = ['Portero', 'Extremo', 'Lateral', 'Central', 'Pivote'];

  Future<void> _loadExistingPlayer() async {
    final existing = await _findProfile(_document.text.trim());
    if (!mounted) return;
    if (existing == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se encontró un perfil con ese documento.')));
      return;
    }
    setState(() {
      _name.text = _firstValue(existing, ['name', 'displayName', 'nombre']) ?? '';
      _number.text = _firstValue(existing, ['number', 'shirtNumber', 'numeroCamiseta', 'jerseyNumber']) ?? '';
      _position.text = _firstValue(existing, ['position', 'posicion']) ?? '';
      _gender = _firstValue(existing, ['gender', 'genero', 'sex', 'sexo']);
      _club.text = _firstValue(existing, ['club', 'clubName', 'club al que pertenece', 'club_name']) ?? '';
    });
  }

  Future<void> _submit() async {
    await _loadExistingPlayer();
    if (!_formKey.currentState!.validate()) return;
    final number = int.parse(_number.text.trim());
    if (widget.usedNumbers.contains(number)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ese número de camiseta ya está asignado.')),
      );
      return;
    }
    final document = _document.text.trim();
    final existing = await _findProfile(document);
    Navigator.of(context).pop({
      'name': _name.text.trim().isNotEmpty ? _name.text.trim() : (existing?['name'] ?? ''),
      'document': document,
      'number': _number.text.trim().isNotEmpty ? _number.text.trim() : (_firstValue(existing ?? {}, ['number', 'shirtNumber', 'numeroCamiseta', 'jerseyNumber']) ?? ''),
      'position': _position.text.trim().isNotEmpty ? _position.text.trim() : (_firstValue(existing ?? {}, ['position', 'posicion']) ?? ''),
      'gender': _gender ?? _firstValue(existing ?? {}, ['gender', 'genero', 'sex', 'sexo']) ?? '',
      'club': _club.text.trim().isNotEmpty ? _club.text.trim() : (_firstValue(existing ?? {}, ['club', 'clubName', 'club al que pertenece', 'club_name']) ?? ''),
    });
  }

  String? _firstValue(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  Future<Map<String, dynamic>?> _findProfile(String document) async {
    final firestore = FirebaseFirestore.instance;
    final merged = <String, dynamic>{};
    var found = false;
    for (final collection in [
      firestore.collection('profile_directory'),
      firestore.collection('users'),
      firestore.collection('referees'),
    ]) {
      try {
        final queries = <Future<QuerySnapshot<Map<String, dynamic>>>>[
          collection.where('document', isEqualTo: document).limit(1).get(),
          for (final field in ['documentNumber', 'numeroDocumento', 'numero_documento', 'cedula'])
            collection.where(field, isEqualTo: document).limit(1).get(),
        ];
        for (final snapshot in await Future.wait(queries)) {
          if (snapshot.docs.isEmpty) continue;
          found = true;
          for (final entry in snapshot.docs.first.data().entries) {
            final value = entry.value?.toString().trim();
            if (value != null && value.isNotEmpty) merged[entry.key] = entry.value;
          }
        }
      } on FirebaseException {
        continue;
      }
    }
    return found ? merged : null;
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
        contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        title: const Row(
          children: [
            Icon(Icons.person_add_alt_1_rounded),
            SizedBox(width: 10),
            Text('Agregar jugador'),
          ],
        ),
        content: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Datos del jugador', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 10),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Nombre completo *', prefixIcon: Icon(Icons.badge_outlined)),
                validator: (value) => value == null || value.trim().isEmpty ? 'Escribe el nombre completo' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _document,
                decoration: InputDecoration(
                  labelText: 'Número de documento *',
                  prefixIcon: const Icon(Icons.credit_card_outlined),
                  suffixIcon: IconButton(onPressed: _loadExistingPlayer, icon: const Icon(Icons.search), tooltip: 'Buscar datos'),
                ),
                onEditingComplete: _loadExistingPlayer,
                onFieldSubmitted: (_) => _loadExistingPlayer(),
                validator: (value) => value == null || value.trim().isEmpty ? 'Escribe el documento' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _number,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Número de camiseta *', hintText: '1 al 99'),
                validator: (value) {
                  final number = int.tryParse(value?.trim() ?? '');
                  if (number == null || number < 1 || number > 99) {
                    return 'Usa un número entre 1 y 99';
                  }
                  if (widget.usedNumbers.contains(number)) {
                    return 'Este número ya está asignado';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _position.text.isEmpty ? null : _position.text,
                decoration: const InputDecoration(labelText: 'Posición *', prefixIcon: Icon(Icons.sports_handball_outlined)),
                items: positions.map((position) => DropdownMenuItem(value: position, child: Text(position))).toList(),
                onChanged: (value) => setState(() => _position.text = value ?? ''),
                validator: (value) => value == null ? 'Selecciona una posición' : null,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _gender,
                decoration: const InputDecoration(labelText: 'Género *', prefixIcon: Icon(Icons.wc_outlined)),
                items: (widget.tournamentBranch == 'masculino'
                        ? const ['masculino']
                        : widget.tournamentBranch == 'femenino'
                            ? const ['femenino']
                            : const ['masculino', 'femenino'])
                    .map((gender) => DropdownMenuItem(value: gender, child: Text(gender == 'masculino' ? 'Masculino' : 'Femenino')))
                    .toList(),
                onChanged: (value) => setState(() => _gender = value),
                validator: (value) => value == null ? 'Selecciona el género' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _club,
                decoration: const InputDecoration(labelText: 'Club al que pertenece', prefixIcon: Icon(Icons.shield_outlined)),
              ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
          FilledButton(onPressed: _submit, child: const Text('Agregar')),
        ],
      );
}

class _TeamRegistrationScreenState extends State<TeamRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _team = TextEditingController();
  final _club = TextEditingController();
  final _coach = TextEditingController();
  final _coachDocument = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _players = <Map<String, String>>[];
  String? _category;
  String _color = 'Verde';
  bool _accepted = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final data = widget.initialRegistration;
    if (data == null) return;
    _team.text = data['teamName']?.toString() ?? '';
    _club.text = data['clubName']?.toString() ?? '';
    _coach.text = data['coachName']?.toString() ?? '';
    _coachDocument.text = data['coachDocument']?.toString() ?? '';
    _phone.text = data['coachPhone']?.toString() ?? '';
    _email.text = data['coachEmail']?.toString() ?? '';
    _category = data['category']?.toString();
    _color = data['uniformColor']?.toString() ?? _color;
    final players = data['players'];
    if (players is List) {
      _players.addAll(
        players.whereType<Map>().map(
          (player) => <String, String>{
            for (final entry in player.entries) entry.key.toString(): entry.value?.toString() ?? '',
          },
        ),
      );
    }
    _accepted = true;
  }

  @override
  void dispose() {
    for (final controller in [_team, _club, _coach, _coachDocument, _phone, _email]) controller.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>?> _findProfile(String document) async {
    final firestore = FirebaseFirestore.instance;
    final collections = [
      firestore.collection('profile_directory'),
      firestore.collection('users'),
      firestore.collection('referees'),
    ];
    for (final collection in collections) {
      try {
        final byDocument = await collection.where('document', isEqualTo: document).limit(1).get();
        if (byDocument.docs.isNotEmpty) return byDocument.docs.first.data();
        for (final field in ['documentNumber', 'numeroDocumento', 'numero_documento', 'cedula']) {
          final byNumber = await collection.where(field, isEqualTo: document).limit(1).get();
          if (byNumber.docs.isNotEmpty) return byNumber.docs.first.data();
        }
      } on FirebaseException {
        continue;
      }
    }
    return null;
  }

  Future<void> _loadExistingCoach() async {
    final document = _coachDocument.text.trim();
    if (document.isEmpty) return;
    final existing = await _findProfile(document);
    if (!mounted) return;
    if (existing == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se encontró un perfil con ese documento.')));
      return;
    }
    setState(() {
      _coach.text = existing['name']?.toString() ?? existing['displayName']?.toString() ?? existing['nombre']?.toString() ?? _coach.text;
      _coachDocument.text = existing['document']?.toString() ?? existing['documentNumber']?.toString() ?? existing['numeroDocumento']?.toString() ?? document;
      _phone.text = existing['phone']?.toString() ?? existing['telefono']?.toString() ?? _phone.text;
      _email.text = existing['email']?.toString() ?? existing['correo']?.toString() ?? _email.text;
    });
  }

  Future<void> _addPlayer() async {
  final result = await Navigator.of(context).push<Map<String, String>>(
    MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('Agregar jugador')),
        body: SafeArea(
          child: _PlayerDialog(
  usedNumbers: _players
            .map((player) => int.tryParse(player['number'] ?? ''))
            .whereType<int>()
            .toSet(),
  tournamentBranch: (_category ?? 'libre|mixto').split('|').last,
          ),
        ),
      ),
    ),
    );
    if (!mounted || result == null) return;
    setState(() => _players.add(result));
  }

  Future<void> _submit() async {
    final deadline = widget.tournament.registrationDeadline;
    if (deadline != null && DateTime.now().isAfter(deadline)) {
      _show('El periodo de inscripción terminó. Las solicitudes ya enviadas sí pueden modificarse.');
      return;
    }
    final minPlayers = widget.tournament.minPlayersPerTeam;
    final maxPlayers = widget.tournament.maxPlayersPerTeam;
    final formIsValid = _formKey.currentState!.validate();
    final issues = <String>[];

    if (!formIsValid) issues.add('Completa correctamente los campos obligatorios del formulario.');
    if (_category == null) issues.add('Selecciona una categoría del torneo.');
    if (_players.length < minPlayers) {
      issues.add('Faltan ${minPlayers - _players.length} jugador(es). El mínimo permitido es $minPlayers.');
    }
    if (_players.length > maxPlayers) {
      issues.add('El equipo tiene ${_players.length} jugadores, pero el máximo permitido es $maxPlayers.');
    }
    if (_coachDocument.text.trim().isEmpty) issues.add('El número de documento del entrenador es obligatorio.');
    if (_email.text.trim().isEmpty || !_email.text.trim().contains('@')) issues.add('El correo del entrenador es obligatorio y debe ser válido.');
    final playerDocuments = _players.map((player) => player['document']?.trim()).whereType<String>().where((document) => document.isNotEmpty).toList();
    if (playerDocuments.toSet().length != playerDocuments.length) issues.add('No puedes registrar dos veces el mismo número de documento.');
    if (!_accepted) issues.add('Debes aceptar el reglamento y confirmar que la información es correcta.');

    if (issues.isNotEmpty) {
      await _showValidationWarning(issues);
      return;
    }
    setState(() => _saving = true);
    try {
      final coachEmail = _email.text.trim().toLowerCase();
      final coachDocument = _coachDocument.text.trim();
      final firestore = FirebaseFirestore.instance;
      final directoryProfile = await _findProfile(coachDocument);
      final existingCoach = directoryProfile;

      final enrichedPlayers = <Map<String, String>>[];
      for (final player in _players) {
        final document = player['document']?.trim() ?? '';
        final matches = await firestore.collection('profile_directory').where('document', isEqualTo: document).limit(1).get();
        final matchesByNumber = matches.docs.isEmpty
            ? await firestore.collection('profile_directory').where('documentNumber', isEqualTo: document).limit(1).get()
            : matches;
        final existing = matchesByNumber.docs.isEmpty ? null : matchesByNumber.docs.first.data();
        enrichedPlayers.add({
          ...?existing?.map((key, value) => MapEntry(key, value?.toString() ?? '')),
          ...player,
          'document': document,
        });
      }
      final currentUser = FirebaseAuth.instance.currentUser;
      final isCoachAccount = currentUser?.email?.trim().toLowerCase() == coachEmail;
      final registrations = FirebaseFirestore.instance
          .collection('tournaments')
          .doc(widget.tournament.id)
          .collection('registrations');
      final registration = widget.registrationId == null
          ? registrations.doc()
          : registrations.doc(widget.registrationId);
      final profileDirectory = firestore.collection('profile_directory');
      final teamData = {
        'id': registration.id,
        'tournamentId': widget.tournament.id,
        'registrationId': registration.id,
        'teamName': _team.text.trim(),
        'clubName': _club.text.trim(),
        'coachName': existingCoach?['nombre'] ?? existingCoach?['name'] ?? _coach.text.trim(),
        'coachDocument': existingCoach?['document'] ?? existingCoach?['documentNumber'] ?? coachDocument,
        'coachPhone': existingCoach?['phone'] ?? _phone.text.trim(),
        'coachEmail': existingCoach?['email'] ?? existingCoach?['correo'] ?? coachEmail,
        'category': _category,
        'uniformColor': _color,
        'logoUrl': null,
        'players': enrichedPlayers,
        'playerCount': _players.length,
        'status': 'pending',
        if (widget.registrationId == null) 'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        if (widget.registrationId != null) 'rejectionReason': FieldValue.delete(),
        if (isCoachAccount) 'coachUid': currentUser!.uid,
      };
      final batch = firestore.batch();
      if (isCoachAccount) {
        for (final player in enrichedPlayers) {
          final document = player['document']?.toString().trim() ?? '';
        if (document.isEmpty) continue;
        final playerMatches = await profileDirectory.where('document', isEqualTo: document).limit(1).get();
        final playerRef = playerMatches.docs.isEmpty ? profileDirectory.doc('document_$document') : playerMatches.docs.first.reference;
        batch.set(playerRef, {
          'name': player['name'] ?? '',
          'document': document,
          'number': player['number'] ?? '',
          'position': player['position'] ?? '',
          'gender': player['gender'] ?? '',
          'club': player['club'] ?? '',
          'roles': ['jugador'],
          'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      }
      batch.set(
        registration,
        {
          ...teamData,
          'verificationMessage': 'Solicitud recibida. Debes esperar a que el administrador verifique la información.',
          'termsAccepted': true,
        },
        SetOptions(merge: true),
      );
      if (isCoachAccount) {
        final directoryRef = profileDirectory.doc(currentUser!.uid);
        batch.set(directoryRef, {
          'name': _coach.text.trim(),
          'document': coachDocument,
          'email': coachEmail,
          'phone': _phone.text.trim(),
          'roles': ['entrenador'],
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        final userRef = firestore.collection('users').doc(currentUser!.uid);
        final teamRef = firestore
            .collection('tournaments')
            .doc(widget.tournament.id)
            .collection('teams')
            .doc(registration.id);
        batch.set(
          userRef,
          {
            'uid': currentUser.uid,
            'email': currentUser.email,
            'nombre': _coach.text.trim(),
            'roles': FieldValue.arrayUnion(['entrenador']),
            'rol': 'entrenador',
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
        batch.set(teamRef, teamData, SetOptions(merge: true));
      }
      await batch.commit().timeout(
        const Duration(seconds: 20),
        onTimeout: () => throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'deadline-exceeded',
          message: 'La conexión con Firebase tardó demasiado. Comprueba tu conexión e inténtalo de nuevo.',
        ),
      );
      if (mounted) {
        _show(widget.registrationId != null
            ? 'Solicitud actualizada y enviada nuevamente para revisión.'
            : isCoachAccount
            ? 'Solicitud enviada y equipo vinculado a tu cuenta. Espera la verificación del administrador.'
            : 'Solicitud enviada. Inicia sesión con la cuenta de este correo para vincular el equipo y recibir el rol de entrenador.');
        Navigator.of(context).pop();
      }
    } on FirebaseException catch (error) {
      final message = switch (error.code) {
        'permission-denied' => 'Firebase rechazó la inscripción. Publica firestore.rules y verifica que el torneo tenga inscripción p��blica.',
        'deadline-exceeded' => error.message ?? 'La conexión con Firebase tardó demasiado. Comprueba tu conexión e inténtalo de nuevo.',
        'unavailable' => 'Firebase no está disponible temporalmente. Comprueba tu conexión e inténtalo de nuevo.',
        _ => error.message ?? 'No se pudo enviar la solicitud.',
      };
      _show(message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _showValidationWarning(List<String> issues) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(Icons.warning_amber_rounded),
            ),
            SizedBox(width: 10),
            Expanded(child: Text('No se puede enviar todavía')),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 280),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Revisa los siguientes puntos:'),
                const SizedBox(height: 10),
                ...issues.map(
                  (issue) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('•  '),
                        Expanded(child: Text(issue)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) => '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  void _show(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categories = widget.tournament.categories.isEmpty ? const ['libre|mixto'] : widget.tournament.categories;
    return Scaffold(
      appBar: AppBar(title: const Text('Inscribir tu equipo')),
      body: Form(
        key: _formKey,
      child: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.rejectionReason?.trim().isNotEmpty == true)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                border: Border.all(color: Theme.of(context).colorScheme.error),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Cambios solicitados:\n${widget.rejectionReason}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text('${widget.tournament.name} · Liga de Balonmano del Caquetá', style: theme.textTheme.bodySmall),
            const SizedBox(height: 3),
            Text('Inscribe tu equipo', style: theme.textTheme.headlineSmall),
            Text('Completa la solicitud. El administrador verificará los datos antes de aprobarla.', style: theme.textTheme.bodySmall),
            Text('Jugadores permitidos: ${widget.tournament.minPlayersPerTeam} a ${widget.tournament.maxPlayersPerTeam}', style: theme.textTheme.labelMedium),
            if (widget.tournament.registrationDeadline != null)
              Text('Inscripciones hasta: ${_formatDate(widget.tournament.registrationDeadline!)}', style: theme.textTheme.labelMedium),
            const SizedBox(height: 16),
            _sectionCard(
              theme,
              icon: Icons.groups_rounded,
              title: 'Datos del equipo',
              children: [
                _field(_team, 'Nombre del equipo *', 'Halcones FC'),
                _field(_club, 'Clubes asociados', 'Escribe varios separados por coma', required: false, maxLines: 2),
              ],
            ),
            _sectionCard(
              theme,
              icon: Icons.tune_rounded,
              title: 'Configuración del torneo',
              children: [
                SizedBox(
                  width: double.infinity,
                  child: DropdownButtonFormField<String>(
                    value: _category,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Categoría *'),
                    items: categories.map((value) => DropdownMenuItem(value: value, child: Text(value.replaceAll('|', ' · '), overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: (value) => setState(() => _category = value),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: DropdownButtonFormField<String>(
                    value: _color,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Color del uniforme *'),
                    items: const ['Verde', 'Azul', 'Rojo', 'Naranja', 'Amarillo', 'Blanco', 'Negro'].map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
                    onChanged: (value) => setState(() => _color = value ?? _color),
                  ),
                ),
              ],
            ),
        const SizedBox(height: 10),
        /* Logo del equipo deshabilitado temporalmente.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: theme.colorScheme.outline),
          ),
          child: Row(
            children: [
              Icon(Icons.image_not_supported_outlined, size: 18, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Logo del equipo deshabilitado temporalmente. Puedes continuar sin logo.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ), */
        const SizedBox(height: 8),
        _sectionCard(
          theme,
          icon: Icons.person_rounded,
          title: 'Datos del entrenador',
          children: [
            _field(_coach, 'Nombre del entrenador *', 'Carlos Herrera'),
            TextFormField(
              controller: _coachDocument,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Documento del entrenador *',
                hintText: '1006514021',
                prefixIcon: const Icon(Icons.credit_card_outlined),
                suffixIcon: IconButton(onPressed: _loadExistingCoach, icon: const Icon(Icons.search), tooltip: 'Buscar datos'),
              ),
              onEditingComplete: _loadExistingCoach,
              onFieldSubmitted: (_) => _loadExistingCoach(),
              validator: (value) => value == null || value.trim().isEmpty ? 'Escribe el documento' : null,
            ),
            Row(children: [Expanded(child: _field(_phone, 'Teléfono *', '300 123 4567')), const SizedBox(width: 8), Expanded(child: _field(_email, 'Correo *', 'equipo@correo.com', email: true))]),
          ],
        ),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Jugadores inscritos (${_players.length})', style: theme.textTheme.titleSmall), TextButton.icon(onPressed: _addPlayer, icon: const Icon(Icons.add), label: const Text('Agregar'))]),
        ..._players.asMap().entries.map(
          (entry) => ListTile(
            dense: true,
            leading: Text('${entry.key + 1}'),
            title: Text(entry.value['name'] as String),
            subtitle: Text(
              '${entry.value['position']} · #${entry.value['number']} · Doc. ${entry.value['document']}\n'
              '${entry.value['club']!.isEmpty ? 'Club independiente' : entry.value['club']}',
            ),
            trailing: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => setState(() => _players.removeAt(entry.key)),
            ),
          ),
        ),
        CheckboxListTile(dense: true, contentPadding: EdgeInsets.zero, value: _accepted, onChanged: (value) => setState(() => _accepted = value ?? false), title: const Text('Acepto el reglamento y confirmo que la información es correcta.')),
        SafeArea(
          top: false,
          minimum: const EdgeInsets.only(bottom: 16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _saving ? null : _submit,
              icon: const Icon(Icons.send_outlined),
              label: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(_saving ? 'Enviando...' : 'Enviar solicitud de inscripción'),
              ),
            ),
          ),
        ),
      ])),
    );
  }

  Widget _sectionCard(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) => Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
  child: Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
              Row(
                children: [
                  Icon(icon, size: 19, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(title, style: theme.textTheme.titleSmall),
                ],
              ),
              const SizedBox(height: 8),
              ...children,
            ],
          ),
        ),
      );

  Widget _field(TextEditingController controller, String label, String hint, {bool required = true, bool email = false, int maxLines = 1}) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: email ? TextInputType.emailAddress : TextInputType.text,
          decoration: InputDecoration(labelText: label, hintText: hint),
          validator: (value) {
            if (!required && (value == null || value.trim().isEmpty)) return null;
            if (value == null || value.trim().isEmpty) return 'Campo obligatorio';
            if (email && !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim())) {
              return 'Escribe un correo válido';
            }
            return null;
          },
        ),
      );
}
