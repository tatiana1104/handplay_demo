import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../domain/models/tournament_models.dart';

/// Solicitud pública para inscribir un equipo en un torneo.
/// La cuenta del entrenador debe provisionarse en backend al aprobarse.
class TeamRegistrationScreen extends StatefulWidget {
  const TeamRegistrationScreen({required this.tournament, super.key});
  final Tournament tournament;

  @override
  State<TeamRegistrationScreen> createState() => _TeamRegistrationScreenState();
}

class _TeamRegistrationScreenState extends State<TeamRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _team = TextEditingController();
  final _club = TextEditingController();
  final _coach = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  String? _category;
  String _color = 'Verde';
  bool _accepted = false;
  bool _saving = false;

  @override
  void dispose() {
    for (final controller in [_team, _club, _coach, _phone, _email]) controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || !_accepted || _category == null) {
      _show('Completa los campos y acepta el reglamento.');
      return;
    }
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance
          .collection('tournaments')
          .doc(widget.tournament.id)
          .collection('registrations')
          .add({
        'teamName': _team.text.trim(),
        'clubName': _club.text.trim(),
        'coachName': _coach.text.trim(),
        'coachPhone': _phone.text.trim(),
        'coachEmail': _email.text.trim().toLowerCase(),
        'category': _category,
        'uniformColor': _color,
        'players': <Map<String, String>>[],
        'status': 'pending',
        'termsAccepted': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        _show('Solicitud enviada. El administrador revisará la inscripción.');
        Navigator.of(context).pop();
      }
    } on FirebaseException catch (error) {
      _show(error.message ?? 'No se pudo enviar la solicitud.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _show(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categories = widget.tournament.categories.isEmpty ? const ['Libre|mixto'] : widget.tournament.categories;
    return Scaffold(
      appBar: AppBar(title: const Text('Inscribir tu equipo')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            Text('${widget.tournament.name} · Liga de Balonmano del Caquetá', style: theme.textTheme.bodySmall),
            const SizedBox(height: 4),
            Text('Inscribir tu equipo', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text('Completa este formulario para postular tu equipo al torneo.', style: theme.textTheme.bodySmall),
            const SizedBox(height: 16),
            _field(_team, 'Nombre del equipo *', 'Halcones FC'),
            _field(_club, 'Club', 'Club Amazonas', required: false),
            DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(labelText: 'Categoría *'),
              items: categories.map((value) => DropdownMenuItem(value: value, child: Text(value.replaceAll('|', ' · ')))).toList(),
              onChanged: (value) => setState(() => _category = value),
            ),
            const SizedBox(height: 12),
            Text('Color del uniforme *', style: theme.textTheme.labelLarge),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: _color,
              decoration: const InputDecoration(labelText: 'Color principal'),
              items: const ['Verde', 'Azul', 'Rojo', 'Naranja', 'Amarillo', 'Blanco', 'Negro'].map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
              onChanged: (value) => setState(() => _color = value ?? _color),
            ),
            const SizedBox(height: 14),
            Text('Datos del entrenador', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            _field(_coach, 'Nombre del entrenador *', 'Carlos Herrera'),
            Row(children: [Expanded(child: _field(_phone, 'Teléfono *', '300 123 4567')), const SizedBox(width: 8), Expanded(child: _field(_email, 'Correo *', 'equipo@correo.com', email: true))]),
            const SizedBox(height: 8),
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              value: _accepted,
              onChanged: (value) => setState(() => _accepted = value ?? false),
              title: const Text('Acepto el reglamento del torneo y confirmo que la información es correcta.'),
            ),
            const SizedBox(height: 8),
            FilledButton(onPressed: _saving ? null : _submit, child: Text(_saving ? 'Enviando...' : 'Enviar solicitud de inscripción')),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController controller, String label, String hint, {bool required = true, bool email = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextFormField(
          controller: controller,
          keyboardType: email ? TextInputType.emailAddress : TextInputType.text,
          decoration: InputDecoration(labelText: label, hintText: hint),
          validator: required ? (value) => value == null || value.trim().isEmpty ? 'Campo obligatorio' : null : null,
        ),
      );
}
