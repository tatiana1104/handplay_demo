import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/tournament_repository.dart';
import '../../domain/models/tournament_models.dart';
import '../../domain/tournament_constants.dart';

/// Formulario exclusivo para administradores de liga.
class CreateTournamentScreen extends StatefulWidget {
  const CreateTournamentScreen({super.key, required this.adminId});
  final String adminId;

  @override
  State<CreateTournamentScreen> createState() => _CreateTournamentScreenState();
}

class _CreateTournamentScreenState extends State<CreateTournamentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _teamLimitController = TextEditingController(text: '10');
  final Set<String> _categories = {};
  String _format = TournamentConstants.formats.first;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _publicRegistration = true;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _teamLimitController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_categories.isEmpty) {
      _showMessage('Selecciona al menos una categoría y rama.');
      return;
    }
    if (_startDate == null || _endDate == null || !_endDate!.isAfter(_startDate!)) {
      _showMessage('Selecciona fechas válidas para el torneo.');
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

      await TournamentRepository().createTournament(Tournament(
        id: '',
        adminId: user.uid,
        name: _nameController.text.trim(),
        status: 'upcoming',
        startDate: _startDate,
        endDate: _endDate,
        format: _format,
        categories: _categories.toList()..sort(),
        teamLimit: int.parse(_teamLimitController.text),
        publicRegistration: _publicRegistration,
        phaseDurations: const {},
      ));
      if (mounted) context.pop();
    } on FirebaseException catch (error) {
      _showMessage(error.code == 'permission-denied' ? 'Firebase rechazó la operación. Despliega firestore.rules y renueva la sesión.' : error.message ?? 'No se pudo crear el torneo.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickDate({required bool start}) async {
    final selected = await showDatePicker(context: context, firstDate: DateTime.now().subtract(const Duration(days: 1)), lastDate: DateTime(2035), initialDate: start ? (_startDate ?? DateTime.now()) : (_endDate ?? _startDate ?? DateTime.now()));
    if (selected != null) setState(() => start ? _startDate = selected : _endDate = selected);
  }

  void _showMessage(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo torneo')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 28),
          children: [
            TextFormField(controller: _nameController, decoration: const InputDecoration(labelText: 'Nombre del torneo *', hintText: 'Interclubes 2026'), validator: (v) => v == null || v.trim().isEmpty ? 'Escribe un nombre' : null),
            const SizedBox(height: 12),
            Text('Categorías incluidas *', style: theme.textTheme.bodySmall),
            const SizedBox(height: 6),
            ...TournamentConstants.categories.map((category) => _CategoryGroup(category: category, selected: _categories, onChanged: () => setState(() {}))),
            const SizedBox(height: 8),
            Text('Puedes seleccionar varias categorías y ramas para el mismo evento.', style: theme.textTheme.bodySmall),
            const SizedBox(height: 14),
            Row(children: [Expanded(child: _DateButton(label: 'Fecha inicio *', value: _startDate, onPressed: () => _pickDate(start: true))), const SizedBox(width: 8), Expanded(child: _DateButton(label: 'Fecha fin *', value: _endDate, onPressed: () => _pickDate(start: false)))]),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(value: _format, decoration: const InputDecoration(labelText: 'Formato *'), items: TournamentConstants.formats.map((value) => DropdownMenuItem(value: value, child: Text(titleCase(value)))).toList(), onChanged: (value) => setState(() => _format = value!),),
            const SizedBox(height: 14),
            TextFormField(controller: _teamLimitController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Cupo de equipos *'), validator: (v) => int.tryParse(v ?? '') == null || int.parse(v!) <= 0 ? 'Indica un cupo válido' : null),
            const SizedBox(height: 8),
            SwitchListTile.adaptive(value: _publicRegistration, onChanged: (v) => setState(() => _publicRegistration = v), title: const Text('Inscripción pública', style: TextStyle(fontWeight: FontWeight.bold)), subtitle: const Text('Los equipos podrán inscribirse ellos mismos con el formulario'), contentPadding: EdgeInsets.zero),
            const SizedBox(height: 14),
            SizedBox(height: 48, child: FilledButton(onPressed: _saving ? null : _submit, child: Text(_saving ? 'Guardando...' : 'Crear torneo'))),
          ],
        ),
      ),
    );
  }
}

class _CategoryGroup extends StatelessWidget {
  const _CategoryGroup({required this.category, required this.selected, required this.onChanged});
  final String category;
  final Set<String> selected;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => Wrap(spacing: 6, runSpacing: 4, children: TournamentConstants.branches.map((branch) {
    final key = '$category|$branch';
    return FilterChip(label: Text('${titleCase(category)} ${titleCase(branch)[0]}'), selected: selected.contains(key), onSelected: (value) { value ? selected.add(key) : selected.remove(key); onChanged(); });
  }).toList());
}

class _DateButton extends StatelessWidget {
  const _DateButton({required this.label, required this.value, required this.onPressed});
  final String label;
  final DateTime? value;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => OutlinedButton(onPressed: onPressed, child: Align(alignment: Alignment.centerLeft, child: Text(value == null ? label : '$label: ${value!.day.toString().padLeft(2, '0')}/${value!.month.toString().padLeft(2, '0')}/${value!.year}')));
}
