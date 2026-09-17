import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/tournament_repository.dart';
import '../../domain/models/tournament_models.dart';
import '../../domain/tournament_constants.dart';

/// Formulario exclusivo para administradores de liga.
class CreateTournamentScreen extends StatefulWidget {
  const CreateTournamentScreen({super.key, required this.adminId, this.tournament});
  final String adminId;
  final Tournament? tournament;

  bool get isEditing => tournament != null;

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
  bool _saving = false;

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
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _teamLimitController.dispose();
    _minPlayersController.dispose();
    _maxPlayersController.dispose();
    super.dispose();
  }

  void _addCategoryBranchIfComplete() {
    if (_selectedCategory == null || _selectedBranch == null) return;

    setState(() {
      _categories.add('$_selectedCategory|$_selectedBranch');
      _selectedCategory = null;
      _selectedBranch = null;
    });
  }

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
    if (_startDate == null) {
      _showMessage('Selecciona la fecha de inicio.');
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

  Future<void> _pickDate({required bool start, bool registration = false}) async {
    final selected = await showDatePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime(2035),
      initialDate: start ? (_startDate ?? DateTime.now()) : (_endDate ?? _startDate ?? DateTime.now()),
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

  void _showMessage(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

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
  const _DateButton({required this.label, required this.value, required this.onPressed});
  final String label;
  final DateTime? value;
  final VoidCallback onPressed;

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
