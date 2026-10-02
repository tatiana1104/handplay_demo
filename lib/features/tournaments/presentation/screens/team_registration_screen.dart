import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../teams/data/club_repository.dart';
import '../../../teams/domain/models/club_model.dart';
import '../../data/team_registration_service.dart';
import '../../domain/models/tournament_models.dart';
import 'player_registration_dialog.dart';
import 'team_registration_form.dart';

/// Solicitud pública para inscribir un equipo y sus jugadores.
class TeamRegistrationScreen extends StatefulWidget {
  /// Creates the screen for a new registration or an existing request.
  const TeamRegistrationScreen({
    required this.tournament,
    this.initialRegistration,
    this.registrationId,
    this.rejectionReason,
    super.key,
  });
  final Tournament tournament;
  final Map<String, dynamic>? initialRegistration;
  final String? registrationId;
  final String? rejectionReason;

  /// ES: Crea el estado que administra la inscripción del equipo.
  /// EN: Creates the state that owns the team registration flow.
  @override
  State<TeamRegistrationScreen> createState() => _TeamRegistrationScreenState();
}

class _TeamRegistrationScreenState extends State<TeamRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _team = TextEditingController();
  final _club = TextEditingController();
  final _clubs = <String>[];
  final _coach = TextEditingController();
  final _coachDocument = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _players = <Map<String, String>>[];
  late final Stream<List<ClubModel>> _officialClubsStream = ClubRepository()
      .watchClubs();
  String? _category;
  String _color = 'Verde';
  bool _accepted = false;
  bool _saving = false;

  /// ES: Restaura los campos al editar y reenviar una solicitud.
  /// EN: Restores fields when editing and resubmitting a request.
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
    _email.text = data['clubEmail']?.toString() ?? '';
    _category = data['category']?.toString();
    _color = data['uniformColor']?.toString() ?? _color;
    final players = data['players'];
    if (players is List) {
      _players.addAll(
        players.whereType<Map>().map(
          (player) => <String, String>{
            for (final entry in player.entries)
              entry.key.toString(): entry.value?.toString() ?? '',
          },
        ),
      );
    }
    _accepted = true;
  }

  /// ES: Libera los controladores de texto de esta pantalla.
  /// EN: Releases this screen's text controllers.
  @override
  void dispose() {
    for (final controller in [
      _team,
      _club,
      _coach,
      _coachDocument,
      _phone,
      _email,
    ])
      controller.dispose();
    super.dispose();
  }

  /// ES: Busca el documento de identidad en las colecciones de perfiles.
  /// EN: Searches profile collections for a matching identity document.
  Future<Map<String, dynamic>?> _findProfile(String document) async {
    final firestore = FirebaseFirestore.instance;
    final collections = [
      firestore.collection('profile_directory'),
      firestore.collection('users'),
      firestore.collection('referees'),
    ];
    for (final collection in collections) {
      try {
        final byDocument = await collection
            .where('document', isEqualTo: document)
            .limit(1)
            .get();
        if (byDocument.docs.isNotEmpty) return byDocument.docs.first.data();
        for (final field in [
          'documentNumber',
          'numeroDocumento',
          'numero_documento',
          'cedula',
        ]) {
          final byNumber = await collection
              .where(field, isEqualTo: document)
              .limit(1)
              .get();
          if (byNumber.docs.isNotEmpty) return byNumber.docs.first.data();
        }
      } on FirebaseException {
        continue;
      }
    }
    return null;
  }

  /// ES: Completa los datos del entrenador encontrados por documento.
  /// EN: Fills coach contact fields using the identity document.
  Future<void> _loadExistingCoach() async {
    final document = _coachDocument.text.trim();
    if (document.isEmpty) return;
    final existing = await _findProfile(document);
    if (!mounted) return;
    if (existing == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se encontró un perfil con ese documento.'),
        ),
      );
      return;
    }
    setState(() {
      _coach.text =
          existing['name']?.toString() ??
          existing['displayName']?.toString() ??
          existing['nombre']?.toString() ??
          _coach.text;
      _coachDocument.text =
          existing['document']?.toString() ??
          existing['documentNumber']?.toString() ??
          existing['numeroDocumento']?.toString() ??
          document;
      _phone.text =
          existing['phone']?.toString() ??
          existing['telefono']?.toString() ??
          _phone.text;
      _email.text =
          existing['email']?.toString() ??
          existing['correo']?.toString() ??
          _email.text;
    });
  }

  /// ES: Abre el formulario del jugador y lo agrega al equipo.
  /// EN: Opens the player form and adds its result to the team.
  Future<void> _addPlayer() async {
    final result = await Navigator.of(context).push<Map<String, String>>(
      MaterialPageRoute(
        builder: (_) => PlayerRegistrationDialog(
          usedNumbers: _players
              .map((player) => int.tryParse(player['number'] ?? ''))
              .whereType<int>()
              .toSet(),
          tournamentBranch: (_category ?? 'libre|mixto').split('|').last,
        ),
      ),
    );
    if (!mounted || result == null) return;
    setState(() => _players.add(result));
  }

  /// ES: Agrega un club no vacío y descarta duplicados sin distinguir mayúsculas.
  /// EN: Adds a non-empty club and ignores case-insensitive duplicates.
  void _addClub() {
    final club = _club.text.trim();
    if (club.isEmpty ||
        _clubs.any((item) => item.toLowerCase() == club.toLowerCase()))
      return;
    setState(() {
      _clubs.add(club);
      _club.clear();
    });
  }

  /// ES: Agrega un club oficial seleccionado, evitando duplicados.
  /// EN: Adds a selected official club while preventing duplicates.
  void _addOfficialClub(String club) {
    final normalizedClub = club.trim().toLowerCase();
    if (normalizedClub.isEmpty ||
        _clubs.any((item) => item.trim().toLowerCase() == normalizedClub)) {
      return;
    }
    setState(() => _clubs.add(club.trim()));
  }

  /// ES: Quita un club de la inscripción actual.
  /// EN: Removes a club from the current registration.
  void _removeClub(String club) => setState(() => _clubs.remove(club));

  /// Creates the coach account and sends a password setup link when needed.
  /// ES: Valida y guarda la solicitud en Firestore, y comunica el resultado.
  /// EN: Validates and saves the request to Firestore, then reports the outcome.
  Future<void> _submit() async {
    _addClub();
    final deadline = widget.tournament.registrationDeadline;
    if (deadline != null && DateTime.now().isAfter(deadline)) {
      _show(
        'El periodo de inscripción terminó. Las solicitudes ya enviadas sí pueden modificarse.',
      );
      return;
    }
    final minPlayers = widget.tournament.minPlayersPerTeam;
    final maxPlayers = widget.tournament.maxPlayersPerTeam;
    final formIsValid = _formKey.currentState!.validate();
    final issues = <String>[];

    if (!formIsValid)
      issues.add(
        'Completa correctamente los campos obligatorios del formulario.',
      );
    if (_category == null) issues.add('Selecciona una categoría del torneo.');
    if (_players.length < minPlayers) {
      issues.add(
        'Faltan ${minPlayers - _players.length} jugador(es). El mínimo permitido es $minPlayers.',
      );
    }
    if (_players.length > maxPlayers) {
      issues.add(
        'El equipo tiene ${_players.length} jugadores, pero el máximo permitido es $maxPlayers.',
      );
    }
    if (_coachDocument.text.trim().isEmpty)
      issues.add('El número de documento del entrenador es obligatorio.');
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_email.text.trim())) {
      issues.add('El correo del entrenador es obligatorio y debe ser válido.');
    }

    /// ES: Normaliza documentos para detectar duplicados de jugadores.
    /// EN: Normalizes identity documents to detect duplicate players.
    String normalizeDocument(String value) =>
        value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final playerDocuments = _players
        .map((player) => normalizeDocument(player['document'] ?? ''))
        .where((document) => document.isNotEmpty)
        .toList();
    final duplicateDocuments = playerDocuments
        .where(
          (document) =>
              playerDocuments.where((item) => item == document).length > 1,
        )
        .toSet();
    if (duplicateDocuments.isNotEmpty)
      issues.add(
        'No puedes registrar dos jugadores con el mismo número de documento.',
      );
    if (!_accepted)
      issues.add(
        'Debes aceptar el reglamento y confirmar que la información es correcta.',
      );

    if (issues.isNotEmpty) {
      await _showValidationWarning(issues);
      return;
    }
    setState(() => _saving = true);
    try {
      final clubEmail = _email.text.trim().toLowerCase();
      final result = await TeamRegistrationService().submit(
        tournamentId: widget.tournament.id,
        registrationId: widget.registrationId,
        teamName: _team.text,
        clubs: _clubs,
        coachName: _coach.text,
        coachDocument: _coachDocument.text,
        coachPhone: _phone.text,
        clubEmail: clubEmail,
        category: _category,
        uniformColor: _color,
        players: _players,
      );
      if (mounted) {
        _show(
          widget.registrationId != null
              ? 'Solicitud actualizada y enviada nuevamente para revisión.'
              : result.isCoachAccount
              ? 'Solicitud enviada y equipo vinculado a tu cuenta. Espera la verificación del administrador.'
              : result.coachLinkSent
              ? 'Solicitud enviada. Enviamos al entrenador un enlace para establecer su contraseña e iniciar sesión.'
              : 'Solicitud enviada. El entrenador deberá usar la recuperación de contraseña para iniciar sesión.',
        );
        Navigator.of(context).pop();
      }
    } on FirebaseException catch (error) {
      final message = switch (error.code) {
        'permission-denied' =>
          'Firebase rechazó la inscripción. Verifica que el torneo tenga la inscripción pública activada y que firestore.rules esté publicado en el proyecto handplaydemo.',
        'deadline-exceeded' =>
          error.message ??
              'La conexión con Firebase tardó demasiado. Comprueba tu conexión e inténtalo de nuevo.',
        'unavailable' =>
          'Firebase no está disponible temporalmente. Comprueba tu conexión e inténtalo de nuevo.',
        _ => error.message ?? 'No se pudo enviar la solicitud.',
      };
      _show(message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// ES: Muestra todos los errores de validación en un diálogo.
  /// EN: Shows all form validation issues in one dialog.
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

  /// ES: Muestra un mensaje breve en la parte inferior de la pantalla.
  /// EN: Shows a brief status message at the bottom of the screen.
  void _show(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  /// ES: Conecta el estado y las acciones con el widget del formulario.
  /// EN: Connects the form state and actions to the presentation widget.
  @override
  Widget build(BuildContext context) => StreamBuilder<List<ClubModel>>(
    stream: _officialClubsStream,
    builder: (context, snapshot) => Scaffold(
      appBar: AppBar(title: const Text('Inscribir tu equipo')),
      body: TeamRegistrationForm(
        tournament: widget.tournament,
        rejectionReason: widget.rejectionReason,
        formKey: _formKey,
        teamController: _team,
        clubController: _club,
        coachController: _coach,
        coachDocumentController: _coachDocument,
        phoneController: _phone,
        clubEmailController: _email,
        clubs: _clubs,
        officialClubs:
            snapshot.data?.map((club) => club.name).toList() ??
            const <String>[],
        players: _players,
        category: _category,
        uniformColor: _color,
        accepted: _accepted,
        saving: _saving,
        onAddClub: _addClub,
        onAddOfficialClub: _addOfficialClub,
        onRemoveClub: _removeClub,
        onLoadExistingCoach: _loadExistingCoach,
        onCategoryChanged: (value) => setState(() => _category = value),
        onUniformColorChanged: (value) =>
            setState(() => _color = value ?? _color),
        onAddPlayer: _addPlayer,
        onRemovePlayer: (index) => setState(() => _players.removeAt(index)),
        onAcceptedChanged: (value) =>
            setState(() => _accepted = value ?? false),
        onSubmit: _submit,
      ),
    ),
  );
}
