import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../domain/models/tournament_models.dart';

/// Solicitud pública para inscribir un equipo y sus jugadores.
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
  final _picker = ImagePicker();
  final _players = <Map<String, String>>[];
  String? _category;
  String _color = 'Verde';
  Uint8List? _logoBytes;
  String? _logoName;
  bool _accepted = false;
  bool _saving = false;

  @override
  void dispose() {
    for (final controller in [_team, _club, _coach, _phone, _email]) controller.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 1200);
    if (file == null) return;
    setState(() {
      _logoBytes = null;
      _logoName = file.name;
    });
    _logoBytes = await file.readAsBytes();
    if (mounted) setState(() {});
  }

  Future<void> _addPlayer() async {
    final name = TextEditingController();
    final number = TextEditingController();
    final position = TextEditingController();
    final added = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Agregar jugador'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Nombre completo')),
          TextField(controller: number, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Número')),
          TextField(controller: position, decoration: const InputDecoration(labelText: 'Posición')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, name.text.trim().isNotEmpty), child: const Text('Agregar')),
        ],
      ),
    );
    if (added == true) setState(() => _players.add({'name': name.text.trim(), 'number': number.text.trim(), 'position': position.text.trim()}));
    name.dispose();
    number.dispose();
    position.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || !_accepted || _category == null || _players.isEmpty) {
      _show('Completa los campos, agrega al menos un jugador y acepta el reglamento.');
      return;
    }
    setState(() => _saving = true);
    try {
      final registration = FirebaseFirestore.instance.collection('tournaments').doc(widget.tournament.id).collection('registrations').doc();
      String? logoPath;
      if (_logoBytes != null) {
        final ref = FirebaseStorage.instance.ref('team-logos/${registration.id}/${_logoName ?? 'logo'}');
        await ref.putData(_logoBytes!, SettableMetadata(contentType: 'image/*'));
        logoPath = await ref.getDownloadURL();
      }
      await registration.set({
        'teamName': _team.text.trim(), 'clubName': _club.text.trim(), 'coachName': _coach.text.trim(),
        'coachPhone': _phone.text.trim(), 'coachEmail': _email.text.trim().toLowerCase(), 'category': _category,
        'uniformColor': _color, 'logoUrl': logoPath, 'players': _players, 'status': 'pending',
        'termsAccepted': true, 'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        _show('Solicitud enviada. Recibirás un correo de confirmación y debes esperar la verificación del administrador.');
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
    final categories = widget.tournament.categories.isEmpty ? const ['libre|mixto'] : widget.tournament.categories;
    return Scaffold(
      appBar: AppBar(title: const Text('Inscribir tu equipo')),
      body: Form(key: _formKey, child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 28), children: [
        Text('${widget.tournament.name} · Liga de Balonmano del Caquetá', style: theme.textTheme.bodySmall),
        Text('Inscribe tu equipo', style: theme.textTheme.headlineSmall),
        Text('La información será revisada antes de confirmar la inscripción.', style: theme.textTheme.bodySmall),
        const SizedBox(height: 14),
        _field(_team, 'Nombre del equipo *', 'Halcones FC'),
        _field(_club, 'Club', 'Club Amazonas', required: false),
        OutlinedButton.icon(onPressed: _pickLogo, icon: const Icon(Icons.upload_file_rounded), label: Text(_logoName == null ? 'Subir logo del equipo' : 'Logo seleccionado')),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(value: _category, decoration: const InputDecoration(labelText: 'Categoría *'), items: categories.map((value) => DropdownMenuItem(value: value, child: Text(value.replaceAll('|', ' · ')))).toList(), onChanged: (value) => setState(() => _category = value)),
        DropdownButtonFormField<String>(value: _color, decoration: const InputDecoration(labelText: 'Color del uniforme *'), items: const ['Verde', 'Azul', 'Rojo', 'Naranja', 'Amarillo', 'Blanco', 'Negro'].map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(), onChanged: (value) => setState(() => _color = value ?? _color)),
        const SizedBox(height: 12),
        Text('Datos del entrenador', style: theme.textTheme.titleMedium),
        _field(_coach, 'Nombre del entrenador *', 'Carlos Herrera'),
        Row(children: [Expanded(child: _field(_phone, 'Teléfono *', '300 123 4567')), const SizedBox(width: 8), Expanded(child: _field(_email, 'Correo *', 'equipo@correo.com', email: true))]),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Jugadores inscritos (${_players.length})', style: theme.textTheme.titleSmall), TextButton.icon(onPressed: _addPlayer, icon: const Icon(Icons.add), label: const Text('Agregar'))]),
        ..._players.asMap().entries.map(
          (entry) => ListTile(
            dense: true,
            leading: Text('${entry.key + 1}'),
            title: Text(entry.value['name'] as String),
            subtitle: Text('${entry.value['position']} · #${entry.value['number']}'),
            trailing: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => setState(() => _players.removeAt(entry.key)),
            ),
          ),
        ),
        CheckboxListTile(dense: true, contentPadding: EdgeInsets.zero, value: _accepted, onChanged: (value) => setState(() => _accepted = value ?? false), title: const Text('Acepto el reglamento y confirmo que la información es correcta.')),
        FilledButton(onPressed: _saving ? null : _submit, child: Text(_saving ? 'Enviando...' : 'Enviar solicitud de inscripción')),
      ])),
    );
  }

  Widget _field(TextEditingController controller, String label, String hint, {bool required = true, bool email = false}) => Padding(padding: const EdgeInsets.only(bottom: 8), child: TextFormField(controller: controller, keyboardType: email ? TextInputType.emailAddress : TextInputType.text, decoration: InputDecoration(labelText: label, hintText: hint), validator: required ? (value) => value == null || value.trim().isEmpty ? 'Campo obligatorio' : null : null));
}
