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
              final accreditation = data['accreditation']?.toString() ?? data['nivel']?.toString() ?? 'municipal';
              return Card(
                child: ListTile(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => RefereeDetailScreen(refereeId: docs[index].id, data: data)),
                  ),
                  leading: CircleAvatar(child: Text(name.substring(0, 1).toUpperCase())),
                  title: Text(name),
                  subtitle: Text(accreditation),
                  trailing: const Icon(Icons.chevron_right),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class RefereeDetailScreen extends StatefulWidget {
  const RefereeDetailScreen({required this.refereeId, required this.data, super.key});
  final String refereeId;
  final Map<String, dynamic> data;

  @override
  State<RefereeDetailScreen> createState() => _RefereeDetailScreenState();
}

class _RefereeDetailScreenState extends State<RefereeDetailScreen> {
  late String _level;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _level = widget.data['accreditation']?.toString() ?? widget.data['nivel']?.toString() ?? 'municipal';
  }

  List<String> get _levels {
    final result = <String>['municipal'];
    if (_level == 'departamental' || _level == 'nacional') result.add('departamental');
    if (_level == 'nacional') result.add('nacional');
    return result;
  }

  String _label(String value) => switch (value) {
        'municipal' => 'Municipal (básico)',
        'departamental' => 'Departamental (intermedio)',
        'nacional' => 'Nacional (alto)',
        _ => value,
      };

  String? get _nextLevel {
    switch (_level) {
      case 'municipal':
        return 'departamental';
      case 'departamental':
        return 'nacional';
      default:
        return null;
    }
  }

  Future<void> _selectNextLevel() async {
    final nextLevel = _nextLevel;
    if (nextLevel == null) return;
    final selectedLevel = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Agregar acreditación'),
        content: DropdownButtonFormField<String>(
          value: nextLevel,
          decoration: const InputDecoration(
            labelText: 'Nivel disponible',
            border: OutlineInputBorder(),
          ),
          items: [DropdownMenuItem(value: nextLevel, child: Text(_label(nextLevel)))],
          onChanged: (value) => Navigator.of(dialogContext).pop(value),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(nextLevel), child: const Text('Continuar')),
        ],
      ),
    );
    if (selectedLevel == null || !mounted) return;
    setState(() => _level = selectedLevel);
    await _saveLevel();
  }

  Future<void> _saveLevel() async {
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(widget.refereeId).update({
        'accreditation': _level,
        'nivel': _level,
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nivel actualizado.')));
    } on FirebaseException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo actualizar: ${error.code}')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.data['displayName']?.toString() ?? widget.data['nombre']?.toString() ?? 'Árbitro';
    final document = widget.data['document']?.toString() ?? widget.data['documentNumber']?.toString() ?? 'No registrado';
    final email = widget.data['email']?.toString() ?? widget.data['correo']?.toString() ?? 'No registrado';
    final phone = widget.data['phone']?.toString() ?? widget.data['telefono']?.toString() ?? 'No registrado';
    return Scaffold(
      appBar: AppBar(title: const Text('Perfil del árbitro')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          CircleAvatar(radius: 32, child: Text(name.substring(0, 1).toUpperCase())),
          const SizedBox(height: 12),
          Center(child: Text(name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700))),
          const SizedBox(height: 20),
          Card(child: ListTile(title: const Text('Documento'), subtitle: Text(document))),
          Card(child: ListTile(title: const Text('Correo'), subtitle: Text(email))),
          Card(child: ListTile(title: const Text('Teléfono'), subtitle: Text(phone))),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Certificaciones',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (_nextLevel != null)
                IconButton(
                  tooltip: 'Habilitar ${_label(_nextLevel!)}',
                  onPressed: _saving ? null : _selectNextLevel,
                  icon: const Icon(Icons.add_circle_outline),
                ),
            ],
          ),
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              dense: true,
              title: Text('Acreditación ${_label(_level)}'),
              trailing: Text('Vigente', style: TextStyle(color: Colors.green.shade400, fontWeight: FontWeight.w600)),
            ),
          ),
          if (_level == 'departamental' || _level == 'nacional')
            Card(
              margin: const EdgeInsets.only(top: 6),
              child: ListTile(
                dense: true,
                title: const Text('Acreditación Municipal (básico)'),
                trailing: Text('Vigente', style: TextStyle(color: Colors.green.shade400, fontWeight: FontWeight.w600)),
              ),
            ),
          if (_level == 'nacional')
            Card(
              margin: const EdgeInsets.only(top: 6),
              child: ListTile(
                dense: true,
                title: const Text('Acreditación Departamental (intermedio)'),
                trailing: Text('Vigente', style: TextStyle(color: Colors.green.shade400, fontWeight: FontWeight.w600)),
              ),
            ),
        ],
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
  String _accreditation = 'municipal';
  String _existingAccreditation = 'municipal';
  DocumentReference<Map<String, dynamic>>? _userRef;

  List<String> get _availableAccreditations {
    final levels = <String>['municipal'];
    if (_userRef != null || _existingAccreditation == 'departamental' || _existingAccreditation == 'nacional') {
      levels.add('departamental');
    }
    if (_existingAccreditation == 'nacional') levels.add('nacional');
    return levels;
  }

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
          _accreditation = 'municipal';
          _existingAccreditation = 'municipal';
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
        final savedLevel = data['accreditation']?.toString() ?? data['nivel']?.toString() ?? 'municipal';
        _existingAccreditation = ['municipal', 'departamental', 'nacional'].contains(savedLevel) ? savedLevel : 'municipal';
        _accreditation = _existingAccreditation;
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
        'uid': data.data()?['uid'] ?? userRef.id,
        'rol': 'arbitro',
        'displayName': _name.text.trim(),
        'email': _email.text.trim(),
        'phone': _phone.text.trim(),
        'document': _document.text.trim(),
        'accreditation': _accreditation,
        'nivel': _accreditation,
        'roles': roles,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (mounted) Navigator.pop(context);
    } on FirebaseException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo guardar el árbitro: ${error.code}')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _levelLabel(String level) => switch (level) {
        'municipal' => 'Municipal (básico)',
        'departamental' => 'Departamental (intermedio)',
        'nacional' => 'Nacional (alto)',
        _ => level,
      };

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
              TextFormField(controller: _email, enabled: _searched, decoration: const InputDecoration(labelText: 'Correo', border: OutlineInputBorder()), keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 12),
              TextFormField(controller: _phone, enabled: _searched, decoration: const InputDecoration(labelText: 'Número de teléfono', border: OutlineInputBorder()), keyboardType: TextInputType.phone),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _availableAccreditations.contains(_accreditation) ? _accreditation : _availableAccreditations.first,
                decoration: const InputDecoration(
                  labelText: 'Acreditación o nivel',
                  hintText: 'Selecciona el nivel del árbitro',
                  prefixIcon: Icon(Icons.workspace_premium_outlined),
                  border: OutlineInputBorder(),
                ),
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down_rounded),
                items: _availableAccreditations.map((level) => DropdownMenuItem(value: level, child: Text(_levelLabel(level)))).toList(),
                onChanged: _searched ? (value) => setState(() => _accreditation = value ?? 'municipal') : null,
              ),
              const SizedBox(height: 8),
              Text('Municipal: básico. Departamental: requiere municipal. Nacional: requiere departamental.', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 20),
              if (!_searched) const Text('Busca por documento para cargar los datos existentes o registrar un árbitro nuevo.'),
              if (_searched && _userRef == null) const Text('Documento no encontrado. Completa los datos para crear el registro del árbitro.'),
              FilledButton.icon(onPressed: _loading || !_searched ? null : _save, icon: const Icon(Icons.save_outlined), label: Text(_loading ? 'Guardando...' : 'Guardar árbitro')),
            ],
          ),
        ),
      );
}
