import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'email': FirebaseAuth.instance.currentUser?.email,
      'documentNumber': _documentController.text.trim(),
      if (widget.role == 'jugador') ...{
        'shirtNumber': int.parse(_shirtController.text.trim()),
        'position': _positionController.text.trim(),
      },
      'profileCompleted': true,
      'profileCompletedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final isPlayer = widget.role == 'jugador';
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
              TextFormField(controller: _shirtController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Número de camiseta', border: OutlineInputBorder()), validator: (value) => int.tryParse(value ?? '') == null ? 'Ingresa un número válido' : null),
              const SizedBox(height: 14),
              TextFormField(controller: _positionController, decoration: const InputDecoration(labelText: 'Posición', border: OutlineInputBorder()), validator: (value) => value == null || value.trim().isEmpty ? 'Ingresa tu posición' : null),
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
