import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key, required this.userId, required this.initialData});

  final String userId;
  final Map<String, dynamic> initialData;

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _document;
  late final TextEditingController _shirtNumber;
  late final TextEditingController _position;
  late final TextEditingController _teamName;
  late final TextEditingController _experience;
  late final TextEditingController _specialty;
  bool _saving = false;

  late final Set<String> _roles;
  bool get _isPlayer => _roles.contains('jugador') || _roles.contains('player');
  bool get _isCoach => _roles.contains('entrenador') || _roles.contains('coach');
  bool get _isReferee => _roles.contains('arbitro') || _roles.contains('referee') || _roles.contains('árbitro');

  @override
  void initState() {
    super.initState();
    String value(String key) => widget.initialData[key]?.toString() ?? '';
    final storedRoles = (widget.initialData['roles'] as List?)?.map((role) => role.toString().trim().toLowerCase()) ?? const <String>[];
    final primaryRole = value('rol').trim().toLowerCase();
    _roles = {...storedRoles, if (primaryRole.isNotEmpty) primaryRole};
    if (_roles.isEmpty) _roles.add('jugador');
    _name = TextEditingController(text: value('displayName').isNotEmpty ? value('displayName') : value('nombre'));
    _phone = TextEditingController(text: value('phone'));
    _document = TextEditingController(text: value('document').isNotEmpty ? value('document') : value('documentNumber'));
    _shirtNumber = TextEditingController(text: value('shirtNumber'));
    _position = TextEditingController(text: value('position'));
    _teamName = TextEditingController(text: value('teamName'));
    _experience = TextEditingController(text: value('experience'));
    _specialty = TextEditingController(text: value('specialty'));
  }

  @override
  void dispose() {
    for (final controller in [_name, _phone, _document, _shirtNumber, _position, _teamName, _experience, _specialty]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final updates = <String, dynamic>{
        'displayName': _name.text.trim(),
        'phone': _phone.text.trim(),
        'document': _document.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (_isPlayer) {
        updates.addAll({
          'shirtNumber': int.tryParse(_shirtNumber.text.trim()),
          'position': _position.text.trim(),
          'teamName': _teamName.text.trim(),
        });
      }
      if (_isCoach) {
        updates['teamName'] = _teamName.text.trim();
        updates['experience'] = _experience.text.trim();
      }
      if (_isReferee) {
        updates['experience'] = _experience.text.trim();
        updates['specialty'] = _specialty.text.trim();
      }
      await FirebaseFirestore.instance.collection('users').doc(widget.userId).set(updates, SetOptions(merge: true));
      await FirebaseAuth.instance.currentUser?.updateDisplayName(_name.text.trim());
      if (mounted) Navigator.of(context).pop(true);
    } on FirebaseException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo guardar (${error.code}).')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _sectionTitle(BuildContext context, String title) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 12),
    child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
  );

  Widget _field(String label, TextEditingController controller, {TextInputType? keyboardType}) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextField(controller: controller, keyboardType: keyboardType, decoration: InputDecoration(labelText: label, border: const OutlineInputBorder())),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Editar perfil')),
    body: ListView(padding: const EdgeInsets.all(24), children: [
      _field('Nombre completo', _name),
      _field('Teléfono', _phone, keyboardType: TextInputType.phone),
      _field('Documento', _document),
      if (_isPlayer) ...[
        _sectionTitle(context, 'Información de jugador'),
        _field('Número de camiseta', _shirtNumber, keyboardType: TextInputType.number),
        _field('Posición', _position),
        _field('Equipo', _teamName),
      ],
      if (_isCoach) ...[
        _sectionTitle(context, 'Información de entrenador'),
        _field('Equipo', _teamName),
        _field('Experiencia', _experience),
      ],
      if (_isReferee) ...[
        _sectionTitle(context, 'Información de árbitro'),
        _field('Experiencia', _experience),
        _field('Especialidad o certificación', _specialty),
      ],
      const SizedBox(height: 8),
      FilledButton.icon(onPressed: _saving ? null : _save, icon: const Icon(Icons.save_outlined), label: Text(_saving ? 'Guardando...' : 'Guardar cambios')),
    ]),
  );
}

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});
  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirmation = TextEditingController();
  bool _saving = false;
  bool _showCurrent = false;
  bool _showNext = false;
  bool _showConfirmation = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _change() async {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email;
    if (user == null || email == null) return;
    if (_current.text.isEmpty || _next.text.length < 6 || _next.text != _confirmation.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Verifica la contraseña actual, usa al menos 6 caracteres y confirma la nueva contraseña.')));
      return;
    }
    setState(() => _saving = true);
    try {
      await user.reauthenticateWithCredential(EmailAuthProvider.credential(email: email, password: _current.text));
      await user.updatePassword(_next.text);
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Contraseña actualizada.'))); Navigator.of(context).pop(); }
    } on FirebaseAuthException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo cambiar la contraseña (${error.code}).')));
    } finally { if (mounted) setState(() => _saving = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Cambiar contraseña')),
    body: ListView(padding: const EdgeInsets.all(24), children: [
      TextField(controller: _current, obscureText: !_showCurrent, decoration: InputDecoration(labelText: 'Contraseña actual', border: const OutlineInputBorder(), suffixIcon: IconButton(tooltip: _showCurrent ? 'Ocultar contraseña' : 'Mostrar contraseña', onPressed: () => setState(() => _showCurrent = !_showCurrent), icon: Icon(_showCurrent ? Icons.visibility_off_outlined : Icons.visibility_outlined)))),
      const SizedBox(height: 14),
      TextField(controller: _next, obscureText: !_showNext, decoration: InputDecoration(labelText: 'Nueva contraseña', helperText: 'Mínimo 6 caracteres', border: const OutlineInputBorder(), suffixIcon: IconButton(tooltip: _showNext ? 'Ocultar contraseña' : 'Mostrar contraseña', onPressed: () => setState(() => _showNext = !_showNext), icon: Icon(_showNext ? Icons.visibility_off_outlined : Icons.visibility_outlined)))),
      const SizedBox(height: 14),
      TextField(controller: _confirmation, obscureText: !_showConfirmation, decoration: InputDecoration(labelText: 'Confirmar nueva contraseña', border: const OutlineInputBorder(), suffixIcon: IconButton(tooltip: _showConfirmation ? 'Ocultar contraseña' : 'Mostrar contraseña', onPressed: () => setState(() => _showConfirmation = !_showConfirmation), icon: Icon(_showConfirmation ? Icons.visibility_off_outlined : Icons.visibility_outlined)))),
      const SizedBox(height: 20),
      FilledButton(onPressed: _saving ? null : _change, child: Text(_saving ? 'Actualizando...' : 'Actualizar contraseña')),
    ]),
  );
}
