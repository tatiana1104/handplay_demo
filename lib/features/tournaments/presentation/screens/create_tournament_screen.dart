import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/tournament_repository.dart';
import '../../domain/models/tournament_models.dart';

/// Formulario exclusivo para administradores de liga.
/// La autorización real se valida de nuevo con las reglas de Firestore.
class CreateTournamentScreen extends StatefulWidget {
  const CreateTournamentScreen({super.key, required this.adminId});

  final String adminId;

  @override
  State<CreateTournamentScreen> createState() => _CreateTournamentScreenState();
}

class _CreateTournamentScreenState extends State<CreateTournamentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _formatController = TextEditingController(text: 'Liga');
  final _teamLimitController = TextEditingController(text: '10');
  DateTime? _startDate;
  DateTime? _endDate;
  bool _publicRegistration = true;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _formatController.dispose();
    _teamLimitController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null || _endDate == null || !_endDate!.isAfter(_startDate!)) {
      _showMessage('Selecciona fechas válidas para el torneo.');
      return;
    }

    setState(() => _saving = true);
    try {
      final tournament = Tournament(
        id: '',
        adminId: widget.adminId,
        name: _nameController.text.trim(),
        status: 'draft',
        startDate: _startDate,
        endDate: _endDate,
        format: _formatController.text.trim(),
        mainVenueId: '',
        teamLimit: int.parse(_teamLimitController.text),
        publicRegistration: _publicRegistration,
        phaseDurations: const {},
      );
      await TournamentRepository().createTournament(tournament);
      if (mounted) context.pop();
    } on FirebaseException catch (error) {
      _showMessage(error.message ?? 'No se pudo crear el torneo.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickDate({required bool start}) async {
    final selected = await showDatePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime(2035),
      initialDate: start ? (_startDate ?? DateTime.now()) : (_endDate ?? _startDate ?? DateTime.now()),
    );
    if (selected == null) return;
    setState(() => start ? _startDate = selected : _endDate = selected);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo torneo')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Text('Crea una nueva liga de balonmano', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text('Completa la información básica para publicar el torneo.', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 24),
            TextFormField(controller: _nameController, decoration: const InputDecoration(labelText: 'Nombre del torneo', hintText: 'Interclubes 2026'), validator: (value) => value == null || value.trim().isEmpty ? 'Escribe un nombre' : null),
            const SizedBox(height: 14),
            TextFormField(controller: _formatController, decoration: const InputDecoration(labelText: 'Formato'), validator: (value) => value == null || value.trim().isEmpty ? 'Escribe un formato' : null),
            const SizedBox(height: 14),
            TextFormField(controller: _teamLimitController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Cupo de equipos'), validator: (value) => int.tryParse(value ?? '') == null || int.parse(value!) <= 0 ? 'Indica un cupo válido' : null),
            const SizedBox(height: 18),
            _DateButton(label: 'Inicio', value: _startDate, onPressed: () => _pickDate(start: true)),
            const SizedBox(height: 10),
            _DateButton(label: 'Finalización', value: _endDate, onPressed: () => _pickDate(start: false)),
            const SizedBox(height: 10),
            SwitchListTile.adaptive(value: _publicRegistration, onChanged: (value) => setState(() => _publicRegistration = value), title: const Text('Inscripción pública'), subtitle: const Text('Permite que los equipos soliciten participar.'), contentPadding: EdgeInsets.zero),
            const SizedBox(height: 22),
            FilledButton.icon(onPressed: _saving ? null : _submit, icon: _saving ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(Icons.add_circle_outline, color: colors.onPrimary), label: Text(_saving ? 'Guardando...' : 'Crear torneo')),
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
  Widget build(BuildContext context) {
    final formatted = value == null ? 'Seleccionar fecha' : '${value!.day.toString().padLeft(2, '0')}/${value!.month.toString().padLeft(2, '0')}/${value!.year}';
    return OutlinedButton.icon(onPressed: onPressed, icon: const Icon(Icons.calendar_today_outlined), label: Align(alignment: Alignment.centerLeft, child: Text('$label: $formatted')));
  }
}
