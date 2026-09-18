import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/route_names.dart';

import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../../shared/widgets/app_bottom_navigation_bar.dart';

class RefereesScreen extends StatefulWidget {
  const RefereesScreen({super.key});

  @override
  State<RefereesScreen> createState() => _RefereesScreenState();
}

class _RefereesScreenState extends State<RefereesScreen> {
  String _selectedAccreditation = 'all';

  @override
  Widget build(BuildContext context) {
    final referees = FirebaseFirestore.instance
        .collection('users')
        .where('roles', arrayContains: 'arbitro')
        .snapshots();

    final authState = context.watch<AuthBloc>().state;
    final isAdmin = authState is AuthAuthenticated && authState.user.roles.any((role) => role == 'admin' || role == 'admin_liga');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Listado de árbitros'),
        actions: isAdmin ? [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: () => context.push(RouteNames.internal, extra: const NewRefereeScreen()),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Nuevo'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
        ] : const [],
      ),
      bottomNavigationBar: AppBottomNavigationBar(
        selectedIndex: 2,
        isAuthenticated: authState is AuthAuthenticated,
        isAdmin: isAdmin,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: referees,
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text('No se pudieron cargar los árbitros.'));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data?.docs ?? const [];
          if (docs.isEmpty) return const Center(child: Text('No hay árbitros registrados.'));
          final certifications = <String>{
            for (final doc in docs)
              (doc.data()['accreditation'] ?? doc.data()['nivel'] ?? 'municipal').toString().trim().toLowerCase(),
          }..removeWhere((value) => value.isEmpty);
          final visibleDocs = _selectedAccreditation == 'all'
              ? docs
              : docs.where((doc) => (doc.data()['accreditation'] ?? doc.data()['nivel'] ?? 'municipal').toString().trim().toLowerCase() == _selectedAccreditation).toList();
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: visibleDocs.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              if (index == 0) {
                final options = ['all', ...certifications.toList()..sort()];
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      for (final option in options) ...[
                        _AccreditationFilterChip(
                          label: option == 'all' ? 'Todas' : _accreditationLabel(option),
                          selected: _selectedAccreditation == option,
                          onTap: () => setState(() => _selectedAccreditation = option),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                );
              }
              final data = visibleDocs[index - 1].data();
              final name = data['displayName']?.toString() ?? data['nombre']?.toString() ?? 'Árbitro sin nombre';
              final accreditation = data['accreditation']?.toString() ?? data['nivel']?.toString() ?? 'municipal';
              return Card(
                child: ListTile(
                  onTap: () => context.push(RouteNames.internal, extra: RefereeDetailScreen(refereeId: visibleDocs[index - 1].id, data: data)),
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

String _accreditationLabel(String value) => switch (value) {
      'municipal' => 'Municipal',
      'departamental' => 'Departamental',
      'nacional' => 'Nacional',
      _ => value[0].toUpperCase() + value.substring(1),
    };

class _AccreditationFilterChip extends StatelessWidget {
  const _AccreditationFilterChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: selected ? colorScheme.primary.withValues(alpha: .22) : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: selected ? colorScheme.primary.withValues(alpha: .45) : colorScheme.outlineVariant.withValues(alpha: .5)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            child: Text(
              label,
              style: TextStyle(
                color: selected ? colorScheme.primary : colorScheme.onSurfaceVariant,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ),
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

  Future<void> _removeRefereeRole() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar rol de árbitro'),
        content: const Text('Se eliminarán únicamente los datos y el rol de árbitro. Sus roles de jugador o entrenador no se modificarán.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final userRef = FirebaseFirestore.instance.collection('users').doc(widget.refereeId);
      final snapshot = await userRef.get();
      final data = snapshot.data() ?? {};
      final roles = (data['roles'] as List?)?.map((role) => role.toString().trim().toLowerCase()).toSet() ?? <String>{};
      roles.removeAll({'arbitro', 'referee'});
      final primaryRole = data['rol']?.toString().trim().toLowerCase();
      final nextPrimaryRole = primaryRole == 'arbitro' || primaryRole == 'referee'
          ? (roles.contains('jugador') ? 'jugador' : roles.contains('entrenador') ? 'entrenador' : roles.firstOrNull)
          : primaryRole;
      await userRef.update({
        'roles': roles.toList(),
        'rol': nextPrimaryRole ?? FieldValue.delete(),
        'accreditation': FieldValue.delete(),
        'refereeId': FieldValue.delete(),
        'refereeProfile': FieldValue.delete(),
        'nivel': FieldValue.delete(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rol de árbitro eliminado sin afectar los demás roles.')));
        context.pop();
      }
    } on FirebaseException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo eliminar: ${error.code}')));
    }
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
    final roles = [
      ...(widget.data['roles'] is List ? List<dynamic>.from(widget.data['roles']) : <dynamic>[]),
      if (widget.data['rol'] != null) widget.data['rol'],
    ].map((role) => role.toString().toLowerCase()).toSet();
    final isPlayer = roles.contains('jugador') || roles.contains('player');
    final isCoach = roles.contains('entrenador') || roles.contains('coach');
    final document = widget.data['document']?.toString() ?? widget.data['documentNumber']?.toString() ?? 'No registrado';
    final email = widget.data['email']?.toString() ?? widget.data['correo']?.toString() ?? 'No registrado';
    final phone = widget.data['phone']?.toString() ?? widget.data['telefono']?.toString() ?? 'No registrado';
    final authState = context.watch<AuthBloc>().state;
    final isAdmin = authState is AuthAuthenticated && authState.user.roles.any((role) => role == 'admin' || role == 'admin_liga');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil del árbitro'),
        actions: [
          if (isAdmin)
            IconButton(
              tooltip: 'Eliminar rol de árbitro',
              onPressed: _saving ? null : _removeRefereeRole,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      bottomNavigationBar: AppBottomNavigationBar(
        selectedIndex: 2,
        isAuthenticated: authState is AuthAuthenticated,
        isAdmin: isAdmin,
      ),
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

class RoleProfileScreen extends StatelessWidget {
  const RoleProfileScreen({required this.title, required this.data, super.key});
  final String title;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final name = data['displayName']?.toString() ?? data['nombre']?.toString() ?? 'Usuario';
    final email = data['email']?.toString() ?? data['correo']?.toString() ?? 'No registrado';
    final phone = data['phone']?.toString() ?? data['telefono']?.toString() ?? 'No registrado';
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          CircleAvatar(radius: 34, child: Text(name.substring(0, 1).toUpperCase())),
          const SizedBox(height: 12),
          Center(child: Text(name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700))),
          const SizedBox(height: 20),
          Card(child: ListTile(title: const Text('Correo'), subtitle: Text(email))),
          Card(child: ListTile(title: const Text('Teléfono'), subtitle: Text(phone))),
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
      final users = FirebaseFirestore.instance.collection('users');
      var userRef = _userRef;
      if (userRef == null) {
        final email = _email.text.trim().toLowerCase();
        final matches = await Future.wait([
          if (email.isNotEmpty) users.where('email', isEqualTo: email).limit(1).get(),
          if (email.isNotEmpty) users.where('correo', isEqualTo: email).limit(1).get(),
          users.where('document', isEqualTo: _document.text.trim()).limit(1).get(),
        ]);
        for (final result in matches) {
          if (result.docs.isNotEmpty) {
            userRef = result.docs.first.reference;
            break;
          }
        }
      }
      userRef ??= users.doc();
      final data = await userRef.get();
      final existingData = data.data() ?? <String, dynamic>{};
      final roles = (existingData['roles'] as List?)
              ?.map((role) => role.toString().trim().toLowerCase())
              .where((role) => role.isNotEmpty)
              .toSet() ??
          <String>{};
      final primaryRole = existingData['rol']?.toString().trim().toLowerCase();
      if (primaryRole != null && primaryRole.isNotEmpty) roles.add(primaryRole);
      roles.add('arbitro');
      await userRef.set({
        'uid': existingData['uid'] ?? userRef.id,
        'rol': FieldValue.delete(),
        'displayName': _name.text.trim().isNotEmpty ? _name.text.trim() : (data.data()?['displayName'] ?? ''),
        'email': _email.text.trim().toLowerCase(),
        'phone': _phone.text.trim(),
        'document': _document.text.trim(),
        'documentNumber': _document.text.trim(),
        'category': _accreditation,
        'correo': FieldValue.delete(),
        'nombre': FieldValue.delete(),
        'telefono': FieldValue.delete(),
        'nivel': FieldValue.delete(),
        'accreditation': _accreditation,
        'roles': roles.toList(),
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
