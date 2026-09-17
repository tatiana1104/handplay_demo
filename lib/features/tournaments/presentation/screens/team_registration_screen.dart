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

class _PlayerDialog extends StatefulWidget {
  const _PlayerDialog({required this.usedNumbers});

  final Set<int> usedNumbers;

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

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final number = int.parse(_number.text.trim());
    if (widget.usedNumbers.contains(number)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ese número de camiseta ya está asignado.')),
      );
      return;
    }
    Navigator.of(context).pop({
      'name': _name.text.trim(),
      'document': _document.text.trim(),
      'number': _number.text.trim(),
      'position': _position.text.trim(),
      'club': _club.text.trim(),
    });
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
                decoration: const InputDecoration(labelText: 'Número de documento *', prefixIcon: Icon(Icons.credit_card_outlined)),
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
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => _PlayerDialog(
        usedNumbers: _players
            .map((player) => int.tryParse(player['number'] ?? ''))
            .whereType<int>()
            .toSet(),
      ),
    );
    if (!mounted || result == null) return;
    setState(() => _players.add(result));
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
      if (_logoBytes != null && _logoBytes!.isNotEmpty) {
        final safeName = (_logoName ?? 'logo').replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
        final ref = FirebaseStorage.instance
            .ref()
            .child('team-logos')
            .child(widget.tournament.id)
            .child(registration.id)
            .child(safeName);
        final upload = await ref.putData(
          _logoBytes!,
          SettableMetadata(contentType: _contentTypeFor(safeName)),
        );
        logoPath = await upload.ref.getDownloadURL();
      }
      await registration.set({
        'teamName': _team.text.trim(), 'clubName': _club.text.trim(), 'coachName': _coach.text.trim(),
        'coachPhone': _phone.text.trim(), 'coachEmail': _email.text.trim().toLowerCase(), 'category': _category,
        'uniformColor': _color, 'logoUrl': logoPath, 'players': _players, 'status': 'pending',
        'verificationMessage': 'Solicitud recibida. Debes esperar a que el administrador verifique la información.',
        'termsAccepted': true, 'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        _show('Solicitud enviada. Recibirás un correo de confirmación y debes esperar la verificación del administrador.');
        Navigator.of(context).pop();
      }
    } on FirebaseException catch (error) {
      final message = switch (error.code) {
        'object-not-found' => 'No se pudo confirmar el logo en Firebase Storage. Selecciónalo nuevamente o envía la solicitud sin logo.',
        'permission-denied' => 'Firebase rechazó la inscripción. Publica firestore.rules y storage.rules, y verifica que el torneo tenga inscripción pública.',
        _ => error.message ?? 'No se pudo enviar la solicitud.',
      };
      _show(message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _contentTypeFor(String filename) {
    final extension = filename.split('.').last.toLowerCase();
    return switch (extension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      _ => 'image/jpeg',
    };
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
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickLogo,
                icon: Icon(_logoName == null ? Icons.upload_file_rounded : Icons.check_circle_rounded),
                label: Text(_logoName == null ? 'Subir logo del equipo' : 'Cambiar logo'),
              ),
            ),
            if (_logoName != null) ...[
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Eliminar logo',
                onPressed: () => setState(() {
                  _logoBytes = null;
                  _logoName = null;
                }),
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: _logoName == null
                ? theme.colorScheme.surfaceContainerHighest
                : theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _logoName == null
                  ? theme.colorScheme.outline
                  : theme.colorScheme.primary,
            ),
          ),
          child: Row(
            children: [
              Icon(
                _logoName == null ? Icons.info_outline_rounded : Icons.verified_rounded,
                size: 18,
                color: _logoName == null
                    ? theme.colorScheme.onSurfaceVariant
                    : theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _logoName == null
                      ? 'Logo opcional. Selecciona una imagen PNG o JPG.'
                      : 'Imagen seleccionada: $_logoName',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
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
        FilledButton(onPressed: _saving ? null : _submit, child: Text(_saving ? 'Enviando...' : 'Enviar solicitud de inscripción')),
      ])),
    );
  }

  Widget _field(TextEditingController controller, String label, String hint, {bool required = true, bool email = false}) => Padding(padding: const EdgeInsets.only(bottom: 8), child: TextFormField(controller: controller, keyboardType: email ? TextInputType.emailAddress : TextInputType.text, decoration: InputDecoration(labelText: label, hintText: hint), validator: required ? (value) => value == null || value.trim().isEmpty ? 'Campo obligatorio' : null : null));
}
