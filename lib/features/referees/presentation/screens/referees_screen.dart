import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class RefereesScreen extends StatelessWidget {
  const RefereesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final referees = FirebaseFirestore.instance
        .collection('users')
        .where('roles', arrayContains: 'arbitro')
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Listado de árbitros'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const NewRefereeScreen()),
              ),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Nuevo'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: referees,
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text('No se pudieron cargar los árbitros.'));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data?.docs ?? const [];
          if (docs.isEmpty) return const Center(child: Text('No hay árbitros registrados.'));
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final data = docs[index].data();
              final name = data['displayName']?.toString() ?? data['nombre']?.toString() ?? 'Árbitro sin nombre';
              final email = data['email']?.toString() ?? '';
              final phone = data['phone']?.toString() ?? data['telefono']?.toString() ?? '';
              return Card(child: ListTile(
                leading: CircleAvatar(child: Text(name.substring(0, 1).toUpperCase())),
                title: Text(name),
                subtitle: Text([email, phone].where((value) => value.isNotEmpty).join(' · ')),
                trailing: const Icon(Icons.sports_outlined),
              ));
            },
          );
        },
      ),
    );
  }
}

class NewRefereeScreen extends StatefulWidget {
  const NewRefereeScreen({super.key});

  @override
  State<NewRefereeScreen> createState() => _NewRefereeScreenState();
}

class _NewRefereeScreenState extends State<NewRefereeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _document = TextEditingController();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  bool _loading = false;
  bool _searched = false;
  DocumentReference<Map<String, dynamic>>? _userRef;

  @override
  void dispose() {
    _document.dispose();
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _findByDocument() async {
    final document = _document.text.trim();
    if (document.isEmpty) return;
    setState(() => _loading = true);
    try {
      final users = await FirebaseFirestore.instance.collection('users').get();
      QueryDocumentSnapshot<Map<String, dynamic>>? match;
      for (final doc in users.docs) {
        final data = doc.data();
        final value = (data['document'] ?? data['documentNumber'] ?? data['numeroDocumento'] ?? data['cedula'])?.toString().trim();
        if (value == document) {
          match = doc;
          break;
        }
      }
      if (!mounted) return;
      if (match == null) {
        setState(() {
          _searched = true;
          _userRef = null;
          _name.clear();
          _email.clear();
          _phone.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No existe un usuario. Puedes completar el formulario para registrarlo.')));
        return;
      }
      final data = match.data();
      setState(() {
        _searched = true;
        _userRef = match!.reference;
        _name.text = data['displayName']?.toString() ?? data['nombre']?.toString() ?? '';
        _email.text = data['email']?.toString() ?? data['correo']?.toString() ?? '';
        _phone.text = data['phone']?.toString() ?? data['telefono']?.toString() ?? '';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || !_searched) return;
    setState(() => _loading = true);
    try {
      final userRef = _userRef ?? FirebaseFirestore.instance.collection('users').doc();
      final data = await userRef.get();
      final roles = List<String>.from(data.data()?['roles'] ?? const <String>[]);
      if (!roles.contains('arbitro')) roles.add('arbitro');
      await userRef.set({
        'displayName': _name.text.trim(),
        'email': _email.text.trim(),
        'phone': _phone.text.trim(),
        'document': _document.text.trim(),
        'roles': roles,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Nuevo árbitro')),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(controller: _document, decoration: const InputDecoration(labelText: 'Número de documento', suffixIcon: Icon(Icons.search), border: OutlineInputBorder()), keyboardType: TextInputType.number, onFieldSubmitted: (_) => _findByDocument(), validator: (value) => value == null || value.trim().isEmpty ? 'Ingresa el documento' : null),
              const SizedBox(height: 12),
              FilledButton.icon(onPressed: _loading ? null : _findByDocument, icon: const Icon(Icons.search), label: const Text('Buscar usuario')),
              const SizedBox(height: 20),
              TextFormField(controller: _name, enabled: _searched, decoration: const InputDecoration(labelText: 'Nombre', border: OutlineInputBorder()), validator: (value) => value == null || value.trim().isEmpty ? 'Campo requerido' : null),
              const SizedBox(height: 12),
              TextFormField(controller: _email, enabled: _found, decoration: const InputDecoration(labelText: 'Correo', border: OutlineInputBorder()), keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 12),
              TextFormField(controller: _phone, enabled: _found, decoration: const InputDecoration(labelText: 'Número de teléfono', border: OutlineInputBorder()), keyboardType: TextInputType.phone),
              const SizedBox(height: 20),
              if (!_searched) const Text('Busca por documento para cargar los datos existentes o registrar un árbitro nuevo.'),
              if (_searched && _userRef == null) const Text('Documento no encontrado. Completa los datos para crear el registro del árbitro.'),
              FilledButton.icon(onPressed: _loading || !_searched ? null : _save, icon: const Icon(Icons.save_outlined), label: Text(_loading ? 'Guardando...' : 'Guardar árbitro')),
            ],
          ),
        ),
      );
}
