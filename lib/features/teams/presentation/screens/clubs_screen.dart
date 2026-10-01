import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../shared/widgets/app_bottom_navigation_bar.dart';
import '../../data/club_repository.dart';
import '../../domain/models/club_model.dart';
import 'club_detail_screen.dart';

/// ES: Permite al administrador mantener el catálogo de clubes oficiales.
/// EN: Lets administrators manage the league's official club catalog.
class ClubsScreen extends StatefulWidget {
  /// ES: Crea la pantalla de administración de clubes.
  /// EN: Creates the club management screen.
  const ClubsScreen({super.key});

  @override
  State<ClubsScreen> createState() => _ClubsScreenState();
}

class _ClubsScreenState extends State<ClubsScreen> {
  final _repository = ClubRepository();
  bool _savingClub = false;

  /// ES: Muestra el catálogo reactivo de clubes y las acciones administrativas.
  /// EN: Displays the live club catalog and administrative actions.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Clubes de la liga')),
      bottomNavigationBar: const AppBottomNavigationBar(
        selectedIndex: 3,
        isAuthenticated: true,
        isAdmin: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editClub(),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo club'),
      ),
      body: StreamBuilder<List<ClubModel>>(
        stream: _repository.watchClubs(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('No se pudieron cargar los clubes.'),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final clubs = snapshot.data!;
          if (clubs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Todavía no hay clubes registrados.'),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
            itemCount: clubs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final club = clubs[index];
              return Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.groups_outlined),
                  ),
                  title: Text(club.name),
                  subtitle: const Text('Ver equipos, jugadores y entrenadores'),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => ClubDetailScreen(club: club)),
                  ),
                  trailing: PopupMenuButton<String>(
                    tooltip: 'Acciones del club',
                    onSelected: (action) {
                      if (action == 'edit') {
                        _editClub(club: club);
                      } else {
                        _deleteClub(club);
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          leading: Icon(Icons.edit_outlined),
                          title: Text('Editar'),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          leading: Icon(Icons.delete_outline),
                          title: Text('Eliminar'),
                        ),
                      ),
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

  /// ES: Solicita el nombre del club y lo crea o actualiza si es único.
  /// EN: Prompts for a club name and creates or updates it if unique.
  Future<void> _editClub({ClubModel? club}) async {
    final formKey = GlobalKey<FormState>();
    final controller = TextEditingController(text: club?.name ?? '');
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(club == null ? 'Registrar club' : 'Editar club'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Nombre oficial del club',
              hintText: 'Club Deportivo Caquetá',
            ),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Escribe el nombre del club'
                : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(dialogContext).pop(controller.text.trim());
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    // showDialog completes after the dialog route is removed. Dispose the
    // controller only then, never from the dialog's save callback.
    controller.dispose();
    if (name == null || !mounted || _savingClub) return;

    setState(() => _savingClub = true);
    try {
      final clubs = await _repository.watchClubs().first;
      if (!mounted) return;
      final duplicate = clubs.any(
        (item) =>
            item.id != club?.id &&
            item.name.trim().toLowerCase() == name.toLowerCase(),
      );
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
        await _repository.createClub(name: name, createdBy: userId);
      } else {
        await _repository.updateClub(ClubModel(id: club.id, name: name));
      }
      if (mounted)
        _showMessage(club == null ? 'Club registrado.' : 'Club actualizado.');
    } on FirebaseException catch (error) {
      if (mounted) _showMessage('No se pudo guardar el club (${error.code}).');
    } finally {
      if (mounted) setState(() => _savingClub = false);
    }
  }

  /// ES: Pide confirmación antes de borrar un club del catálogo oficial.
  /// EN: Asks for confirmation before deleting a club from the official catalog.
  Future<void> _deleteClub(ClubModel club) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar club'),
        content: Text('¿Eliminar "${club.name}" del catálogo de clubes?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Eliminar'),
          ),
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

  /// ES: Muestra el resultado de una acción mediante un SnackBar.
  /// EN: Shows an action result using a SnackBar.
  void _showMessage(String message) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    });
  }
}
