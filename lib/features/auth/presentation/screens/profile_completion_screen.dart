import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/route_names.dart';

class ProfileCompletionScreen extends StatefulWidget {
  const ProfileCompletionScreen({super.key, required this.role});
  final String role;

  @override
  State<ProfileCompletionScreen> createState() => _ProfileCompletionScreenState();
}

class _ProfileCompletionScreenState extends State<ProfileCompletionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _documentController = TextEditingController();
  final _shirtController = TextEditingController();
  final _positionController = TextEditingController();
  static const _playerPositions = ['Portero', 'Extremo', 'Lateral', 'Central', 'Pivote'];
  static const int _minShirtNumber = 1;
  static const int _maxShirtNumber = 99;
  bool _saving = false;

  @override
  void dispose() {
    _documentController.dispose();
    _shirtController.dispose();
    _positionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _saving = true);
    final currentUser = FirebaseAuth.instance.currentUser!;
    final normalizedRole = switch (widget.role.trim().toLowerCase()) {
      'player' || 'jugador' => 'jugador',
      'coach' || 'entrenador' => 'entrenador',
      'referee' || 'arbitro' || 'árbitro' => 'arbitro',
      'public' || 'publico' || 'público' => 'publico',
      'admin' || 'admin_liga' => widget.role.trim().toLowerCase(),
      _ => 'jugador',
    };
    try {
      final profileRef = FirebaseFirestore.instance.collection('users').doc(uid);
      final existingSnapshot = await profileRef.get();
      final existingData = existingSnapshot.data() ?? const <String, dynamic>{};
      final existingRoles = (existingData['roles'] as List?)
              ?.whereType<String>()
              .map((role) => switch (role.trim().toLowerCase()) {
                    'player' || 'jugador' => 'jugador',
                    'coach' || 'entrenador' => 'entrenador',
                    'referee' || 'arbitro' || 'árbitro' => 'arbitro',
                    'public' || 'publico' || 'público' => 'publico',
                    _ => role.trim().toLowerCase(),
                  })
              .where((role) => ['jugador', 'entrenador', 'arbitro', 'publico', 'admin', 'admin_liga'].contains(role))
              .toSet() ?? <String>{};
      existingRoles.add(normalizedRole);
      await profileRef.set({
      'uid': uid,
      'roles': existingRoles.toList(),
      'rol': normalizedRole,
      'profileCompletedByRole': {
        ...((existingData['profileCompletedByRole'] as Map?)?.map((key, value) => MapEntry(key.toString(), value)) ?? const <String, dynamic>{}),
        normalizedRole: true,
      },
      'email': currentUser.email,
      'nombre': existingData['nombre'] ?? currentUser.displayName ?? '',
      'documentNumber': _documentController.text.trim(),
      if (normalizedRole == 'jugador') ...{
        'shirtNumber': int.parse(_shirtController.text.trim()),
        'position': _positionController.text.trim(),
      },
      'profileCompleted': true,
      'profileComplete': true,
      'profileCompletedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      final savedSnapshot = await profileRef.get(const GetOptions(source: Source.server));
      final savedData = savedSnapshot.data();
      if (!savedSnapshot.exists || savedData?['profileCompleted'] != true) {
        throw StateError('Firestore no confirmó el perfil guardado');
      }
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Perfil guardado correctamente')));
      context.go(RouteNames.profile);
    } on FirebaseException catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo guardar el perfil: ${error.message ?? error.code}')));
    } on FormatException {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('El número de camiseta no es válido')));
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo guardar el perfil: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPlayer = switch (widget.role.trim().toLowerCase()) {
      'player' || 'jugador' => true,
      _ => false,
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Completa tu perfil')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text('Necesitamos algunos datos para completar tu registro.'),
            const SizedBox(height: 20),
            TextFormField(controller: _documentController, decoration: const InputDecoration(labelText: 'Número de documento', border: OutlineInputBorder()), validator: (value) => value == null || value.trim().isEmpty ? 'Ingresa tu documento' : null),
            if (isPlayer) ...[
              const SizedBox(height: 14),
              TextFormField(
                controller: _shirtController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Número de camiseta', border: OutlineInputBorder()),
                validator: (value) {
                  final number = int.tryParse(value ?? '');
                  return number == null || number < _minShirtNumber || number > _maxShirtNumber
                      ? 'Ingresa un número entre $_minShirtNumber y $_maxShirtNumber'
                      : null;
                },
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: _playerPositions.contains(_positionController.text) ? _positionController.text : null,
                decoration: const InputDecoration(labelText: 'Posición', border: OutlineInputBorder(), prefixIcon: Icon(Icons.sports_handball_outlined)),
                items: _playerPositions.map((position) => DropdownMenuItem(value: position, child: Text(position))).toList(),
                onChanged: _saving ? null : (value) => setState(() => _positionController.text = value ?? ''),
                validator: (value) => value == null || value.isEmpty ? 'Selecciona una posición' : null,
              ),
            ],
            const SizedBox(height: 14),
            TextFormField(initialValue: FirebaseAuth.instance.currentUser?.email ?? '', readOnly: true, decoration: const InputDecoration(labelText: 'Correo electrónico', border: OutlineInputBorder())),
            const SizedBox(height: 24),
            FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Guardando...' : 'Guardar perfil')),
          ],
        ),
      ),
    );
  }
}
