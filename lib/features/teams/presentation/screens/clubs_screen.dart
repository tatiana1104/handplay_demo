import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../shared/widgets/app_bottom_navigation_bar.dart';
import '../../data/club_repository.dart';
import '../../domain/models/club_model.dart';
import 'club_detail_screen.dart';

class ClubsScreen extends StatefulWidget {
  const ClubsScreen({super.key});

  @override
  State<ClubsScreen> createState() => _ClubsScreenState();
}

class _ClubsScreenState extends State<ClubsScreen> {
  final _repository = ClubRepository();
  bool _savingClub = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Clubes de la liga')),
      bottomNavigationBar: const AppBottomNavigationBar(selectedIndex: 3, isAuthenticated: true, isAdmin: true),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editClub(),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo club'),
      ),
      body: StreamBuilder<List<ClubModel>>(
        stream: _repository.watchClubs(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text('No se pudieron cargar los clubes.'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final clubs = snapshot.data!;
          if (clubs.isEmpty) return const Center(child: Text('Todavía no hay clubes registrados.'));
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
            itemCount: clubs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final club = clubs[index];
              return Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.groups_outlined)),
                  title: Text(club.name),
                  subtitle: const Text('Ver equipos, jugadores y entrenadores'),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ClubDetailScreen(club: club))),
                  trailing: PopupMenuButton<String>(
                    tooltip: 'Acciones del club',
                    onSelected: (action) => action == 'edit' ? _editClub(club: club) : _deleteClub(club),
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('Editar'))),
                      PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete_outline), title: Text('Eliminar'))),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _editClub({ClubModel? club}) async {
    final result = await showDialog<({String name, String assistantName, String assistantEmail})>(context: context, builder: (_) => _ClubEditDialog(club: club));
    final name = result?.name;
    if (name == null || !mounted || _savingClub) return;
    setState(() => _savingClub = true);
    try {
      final clubs = await _repository.watchClubs().first;
      if (!mounted) return;
      final duplicate = clubs.any((item) => item.id != club?.id && item.name.trim().toLowerCase() == name.toLowerCase());
      if (duplicate) {
        _showMessage('Ya existe un club con ese nombre.');
        return;
      }
      if (club == null) {
        final userId = FirebaseAuth.instance.currentUser?.uid;
        if (userId == null) {
          _showMessage('Inicia sesión como administrador para crear un club.');
          return;
        }
        await _repository.createClub(name: name, createdBy: userId, assistantName: result?.assistantName ?? '', assistantEmail: result?.assistantEmail ?? '');
      } else {
        await _repository.updateClub(ClubModel(id: club.id, name: name, assistantName: result?.assistantName ?? '', assistantEmail: result?.assistantEmail ?? ''));
      }
      if (mounted) _showMessage(club == null ? 'Club registrado.' : 'Club actualizado.');
    } on FirebaseException catch (error) {
      if (mounted) _showMessage('No se pudo guardar el club (${error.code}).');
    } finally {
      if (mounted) setState(() => _savingClub = false);
    }
  }

  Future<void> _deleteClub(ClubModel club) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar club'),
        content: Text('¿Eliminar "${club.name}" del catálogo de clubes?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _repository.deleteClub(club.id);
      if (mounted) _showMessage('Club eliminado.');
    } on FirebaseException catch (error) {
      if (mounted) _showMessage('No se pudo eliminar el club (${error.code}).');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(content: Text(message)));
    });
  }
}

class _ClubEditDialog extends StatefulWidget {
  const _ClubEditDialog({this.club});
  final ClubModel? club;

  @override
  State<_ClubEditDialog> createState() => _ClubEditDialogState();
}

class _ClubEditDialogState extends State<_ClubEditDialog> {
  late final TextEditingController _controller;
  late final TextEditingController _assistantName;
  late final TextEditingController _assistantEmail;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.club?.name ?? '');
    _assistantName = TextEditingController(text: widget.club?.assistantName ?? '');
    _assistantEmail = TextEditingController(text: widget.club?.assistantEmail ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    _assistantName.dispose();
    _assistantEmail.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.club == null ? 'Registrar club' : 'Editar club'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _controller,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nombre oficial del club', hintText: 'Club Deportivo Caquetá'),
              validator: (value) => value == null || value.trim().isEmpty ? 'Escribe el nombre del club' : null,
            ),
            TextFormField(controller: _assistantName, decoration: const InputDecoration(labelText: 'Asistente del club (opcional)')),
            TextFormField(controller: _assistantEmail, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Correo del asistente (opcional)')),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.of(context).pop((name: _controller.text.trim(), assistantName: _assistantName.text.trim(), assistantEmail: _assistantEmail.text.trim()));
            }
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
