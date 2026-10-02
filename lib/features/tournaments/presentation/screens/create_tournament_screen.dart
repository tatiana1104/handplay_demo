import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/tournament_repository.dart';
import '../../domain/models/tournament_models.dart';
import '../../domain/tournament_constants.dart';

/// ES: Formulario exclusivo para administradores de liga.
/// EN: Tournament form reserved for league administrators.
class CreateTournamentScreen extends StatefulWidget {
  /// ES: Crea el formulario para crear o editar un torneo.
  /// EN: Creates the form for creating or editing a tournament.
  const CreateTournamentScreen({super.key, required this.adminId, this.tournament});
  final String adminId;
  final Tournament? tournament;

  /// ES: Indica si el formulario está editando un torneo existente.
  /// EN: Indicates whether the form is editing an existing tournament.
  bool get isEditing => tournament != null;

  /// ES: Crea el estado que administra los datos del formulario.
  /// EN: Creates the state that manages the form data.
  @override
  State<CreateTournamentScreen> createState() => _CreateTournamentScreenState();
}

class _CreateTournamentScreenState extends State<CreateTournamentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _teamLimitController = TextEditingController(text: '0');
  final _minPlayersController = TextEditingController(text: '7');
  final _maxPlayersController = TextEditingController(text: '16');
  final Set<String> _categories = {};
  String? _selectedCategory;
  String? _selectedBranch;
  String _format = TournamentConstants.formats.first;
  DateTime? _startDate;
  DateTime? _endDate;
  DateTime? _registrationDeadline;
  bool _publicRegistration = true;
  final _groupCountController = TextEditingController(text: '2');
  final _advancingPositionsController = TextEditingController(text: '1,2');
  bool _saving = false;

  /// ES: Carga los datos iniciales cuando se abre en modo edición.
  /// EN: Loads initial values when the screen opens in edit mode.
  @override
  void initState() {
    super.initState();
    final tournament = widget.tournament;
    if (tournament != null) {
      _nameController.text = tournament.name;
      _teamLimitController.text = tournament.teamLimit.toString();
      _minPlayersController.text = tournament.minPlayersPerTeam.toString();
      _maxPlayersController.text = tournament.maxPlayersPerTeam.toString();
      _categories.addAll(tournament.categories);
      _format = TournamentConstants.formats.contains(tournament.format)
          ? tournament.format
          : TournamentConstants.formats.first;
      _startDate = tournament.startDate;
      _endDate = tournament.endDate;
      _registrationDeadline = tournament.registrationDeadline;
      _publicRegistration = tournament.publicRegistration;
      _groupCountController.text = tournament.groupCount.toString();
      _advancingPositionsController.text = tournament.advancingPositions.join(',');
    }
  }

  /// ES: Libera los controladores de texto del formulario.
  /// EN: Releases the form's text controllers.
  @override
  void dispose() {
    _nameController.dispose();
    _teamLimitController.dispose();
    _minPlayersController.dispose();
    _maxPlayersController.dispose();
    _groupCountController.dispose();
    _advancingPositionsController.dispose();
    super.dispose();
  }

  /// ES: Agrega la combinación de categoría y rama cuando ambas están elegidas.
  /// EN: Adds a category/branch pair once both values are selected.
  void _addCategoryBranchIfComplete() {
    if (_selectedCategory == null || _selectedBranch == null) return;

    setState(() {
      _categories.add('$_selectedCategory|$_selectedBranch');
      _selectedCategory = null;
      _selectedBranch = null;
    });
  }

  /// ES: Valida los datos y crea o actualiza el torneo en Firestore.
  /// EN: Validates the form and creates or updates the Firestore tournament.
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final minPlayers = int.tryParse(_minPlayersController.text);
    final maxPlayers = int.tryParse(_maxPlayersController.text);
    if (minPlayers == null || maxPlayers == null || minPlayers < 1 || maxPlayers < minPlayers) {
      _showMessage('Define un mínimo válido y un máximo mayor o igual.');
      return;
    }
    if (_categories.isEmpty) {
      _showMessage('Agrega al menos una categoría y rama.');
      return;
    }
    final groupCount = _format == 'por_grupos' ? int.tryParse(_groupCountController.text) ?? 0 : 0;
    final advancingPositions = _format == 'por_grupos'
        ? (() {
            final positions = _advancingPositionsController.text
                .split(',')
                .map((value) => int.tryParse(value.trim()))
                .whereType<int>()
                .where((value) => value > 0)
                .toSet()
                .toList();
            positions.sort();
            return positions;
          })()
        : <int>[];
    if (_format == 'por_grupos' && (groupCount < 2 || advancingPositions.isEmpty)) {
      _showMessage('Define al menos 2 grupos y las posiciones que avanzan.');
      return;
    }
    final today = _dateOnly(DateTime.now());
    if (_startDate == null) {
      _showMessage('Selecciona la fecha de inicio.');
      return;
    }
    if (_startDate!.isBefore(today) ||
        (_endDate != null && _endDate!.isBefore(today)) ||
        (_registrationDeadline != null && _registrationDeadline!.isBefore(today))) {
      _showMessage('Las fechas del torneo no pueden ser anteriores a hoy.');
      return;
    }
    if (_registrationDeadline != null && _registrationDeadline!.isAfter(_startDate!)) {
      _showMessage('La fecha límite debe ser anterior al inicio del torneo.');
      return;
    }
    if (_endDate != null && !_endDate!.isAfter(_startDate!)) {
      _showMessage('La fecha fin debe ser posterior a la fecha de inicio.');
      return;
    }

    final phaseOneRounds = _format == 'todos_contra_todos'
        ? (((int.tryParse(_teamLimitController.text) ?? 0) - 1).clamp(0, 999)).toInt()
        : (((int.tryParse(_teamLimitController.text) ?? 0) ~/ groupCount).clamp(0, 999)).toInt();

    setState(() => _saving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw FirebaseException(plugin: 'firebase_auth', code: 'unauthenticated', message: 'Inicia sesión para crear un torneo.');
      final claims = (await user.getIdTokenResult(true)).claims ?? {};
      final role = claims['rol'];
      if (role != 'admin' && role != 'admin_liga') {
        throw FirebaseException(plugin: 'firebase_auth', code: 'permission-denied', message: 'Tu cuenta no tiene permisos de administrador de liga.');
      }

      final tournament = Tournament(
        id: widget.tournament?.id ?? '',
        adminId: user.uid,
        name: _nameController.text.trim(),
        status: TournamentConstants.statuses[1],
        startDate: _startDate,
        endDate: _endDate,
        format: _format,
        categories: _categories.toList()..sort(),
        teamLimit: int.tryParse(_teamLimitController.text) ?? 0,
        minPlayersPerTeam: minPlayers,
        maxPlayersPerTeam: maxPlayers,
        publicRegistration: _publicRegistration,
        registrationDeadline: _registrationDeadline,
        phaseDurations: widget.tournament?.phaseDurations ?? const {},
        groupCount: groupCount,
        advancingPositions: advancingPositions,
        phaseOneRounds: phaseOneRounds,
      );
      if (widget.isEditing) {
        await TournamentRepository().updateTournament(tournament);
      } else {
        await TournamentRepository().createTournament(tournament);
      }
      if (mounted) context.pop();
    } on FirebaseException catch (error) {
      _showMessage(error.code == 'permission-denied' ? 'Firebase rechazó la operación. Despliega firestore.rules y renueva la sesión.' : error.message ?? 'No se pudo crear el torneo.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// ES: Abre un selector de fecha y guarda la fecha elegida en el campo adecuado.
  /// EN: Opens a date picker and stores its value in the selected date field.
  Future<void> _pickDate({required bool start, bool registration = false}) async {
    final today = _dateOnly(DateTime.now());
    final currentDate = registration
        ? _registrationDeadline
        : start
            ? _startDate
            : _endDate;
    final candidateInitialDate = currentDate ?? _startDate ?? today;
    final initialDate = candidateInitialDate.isBefore(today) ? today : candidateInitialDate;
    final selected = await showDatePicker(
      context: context,
      firstDate: today,
      lastDate: DateTime(2035),
      initialDate: initialDate,
    );
    if (selected != null) {
      setState(() {
        if (registration) {
          _registrationDeadline = selected;
        } else if (start) {
          _startDate = selected;
        } else {
          _endDate = selected;
        }
      });
    }
  }

  /// ES: Elimina la hora para comparar fechas por día calendario.
  /// EN: Removes the time component for calendar-day comparisons.
  static DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

  /// ES: Muestra un mensaje breve de validación u operación.
  /// EN: Shows a brief validation or operation message.
  void _showMessage(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  /// ES: Construye el formulario y sus controles de configuración del torneo.
  /// EN: Builds the form and the tournament configuration controls.
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.isEditing ? 'Editar torneo' : 'Nuevo torneo')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
          children: [
            TextFormField(controller: _nameController, decoration: const InputDecoration(labelText: 'Nombre del torneo *', hintText: 'Interclubes 2026'), validator: (v) => v == null || v.trim().isEmpty ? 'Escribe un nombre' : null),
            const SizedBox(height: 8),
            Text('Categorías y ramas *', style: theme.textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(
              'Selecciona una categoría y una rama. La combinación se agregará automáticamente; puedes repetirlo para crear varias.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: TournamentConstants.categories.contains(_selectedCategory) ? _selectedCategory : null,
                  decoration: const InputDecoration(labelText: 'Categoría'),
                  items: TournamentConstants.categories
                      .map((value) => DropdownMenuItem(value: value, child: Text(titleCase(value))))
                      .toList(),
                  onChanged: (value) {
                    setState(() => _selectedCategory = value);
                    _addCategoryBranchIfComplete();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: TournamentConstants.branches.contains(_selectedBranch) ? _selectedBranch : null,
                  decoration: const InputDecoration(labelText: 'Rama'),
                  items: TournamentConstants.branches
                      .map((value) => DropdownMenuItem(value: value, child: Text(titleCase(value))))
                      .toList(),
                  onChanged: (value) {
                    setState(() => _selectedBranch = value);
                    _addCategoryBranchIfComplete();
                  },
                ),
              ),
            ]),
            if (_categories.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('Combinaciones seleccionadas', style: theme.textTheme.labelMedium),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: _categories
                    .map((value) => InputChip(
                          label: Text(value.split('|').map(titleCase).join(' · ')),
                          onDeleted: () => setState(() => _categories.remove(value)),
                        ))
                    .toList(),
              ),
            ],
            const SizedBox(height: 10),
            Row(children: [Expanded(child: _DateButton(label: 'Fecha inicio *', value: _startDate, onPressed: () => _pickDate(start: true))), const SizedBox(width: 8), Expanded(child: _DateButton(label: 'Fecha fin (opcional)', value: _endDate, onPressed: () => _pickDate(start: false)))]),
            const SizedBox(height: 8),
            _DateButton(label: 'Límite de inscripción (opcional)', value: _registrationDeadline, onPressed: () => _pickDate(start: false, registration: true)),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(value: TournamentConstants.formats.contains(_format) ? _format : null, decoration: const InputDecoration(labelText: 'Formato *'), items: TournamentConstants.formats.map((value) => DropdownMenuItem(value: value, child: Text(titleCase(value)))).toList(), onChanged: (value) => setState(() => _format = value!)),
            if (_format == 'por_grupos') ...[
              const SizedBox(height: 10),
              TextFormField(controller: _groupCountController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Grupos fase 1 *', hintText: 'Ejemplo: 4')),
              const SizedBox(height: 8),
              TextFormField(controller: _advancingPositionsController, keyboardType: TextInputType.text, decoration: const InputDecoration(labelText: 'Posiciones que avanzan a fase 2 *', hintText: 'Ejemplo: 1,2', helperText: 'Escribe las posiciones separadas por coma. Los cruces de fase 2 los crea el administrador.')),
            ],
            const SizedBox(height: 10),
            TextFormField(controller: _teamLimitController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Cupo de equipos (opcional)', hintText: 'Déjalo en 0 si no hay límite'), validator: (v) => int.tryParse(v ?? '') == null || int.parse(v!) < 0 ? 'Indica 0 o un número positivo' : null),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: TextFormField(controller: _minPlayersController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Mínimo jugadores *'), validator: (v) => int.tryParse(v ?? '') == null || int.parse(v!) < 1 ? 'Mínimo: 1' : null)),
              const SizedBox(width: 8),
              Expanded(child: TextFormField(controller: _maxPlayersController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Máximo jugadores *'), validator: (v) => int.tryParse(v ?? '') == null || int.parse(v!) < 1 ? 'Indica un máximo' : null)),
            ]),
            const SizedBox(height: 8),
            SwitchListTile.adaptive(
              dense: true,
              visualDensity: VisualDensity.compact,
              value: _publicRegistration,
              onChanged: (v) => setState(() => _publicRegistration = v),
              title: const Text('Inscripción pública', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Los equipos podrán inscribirse ellos mismos.'),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 8),
            SizedBox(height: 48, child: FilledButton(onPressed: _saving ? null : _submit, child: Text(_saving ? 'Guardando...' : widget.isEditing ? 'Guardar cambios' : 'Crear torneo'))),
          ],
        ),
      ),
    );
  }
}

class _DateButton extends StatelessWidget {
  /// ES: Crea un botón que muestra una etiqueta o una fecha seleccionada.
  /// EN: Creates a button that shows a label or a selected date.
  const _DateButton({required this.label, required this.value, required this.onPressed});
  final String label;
  final DateTime? value;
  final VoidCallback onPressed;

  /// ES: Construye el botón de fecha con su valor legible.
  /// EN: Builds the date button with its readable value.
  @override
  Widget build(BuildContext context) => OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(44),
          padding: const EdgeInsets.symmetric(horizontal: 10),
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            value == null ? label : '$label: ${value!.day.toString().padLeft(2, '0')}/${value!.month.toString().padLeft(2, '0')}/${value!.year}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
}
