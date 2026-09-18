import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import '../../domain/entities/app_user.dart';
import '../../../../shared/widgets/app_bottom_navigation_bar.dart';
import '../../../../core/routing/route_names.dart';
import 'profile_completion_screen.dart';

/// Vista de la cuenta actualmente autenticada.
/// Firebase Auth es la fuente de verdad para el correo y el nombre visible.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  static String _roleLabel(String role) {
    switch (role) {
      case 'admin':
      case 'admin_liga':
        return 'Administrador';
      case 'arbitro':
        return 'Árbitro';
      case 'entrenador':
        return 'Entrenador';
      case 'jugador':
        return 'Jugador';
      default:
        return role;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final user = authState is AuthAuthenticated ? authState.user : null;
    final displayName = _displayName(user);
    final email = user?.email ?? 'Sin correo disponible';
    final roleLabel = user == null
      ? 'Usuario'
      : user.roles.map(_roleLabel).join(', ');

    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, snapshot) {
        final profile = snapshot.data?.data() ?? const <String, dynamic>{};
        final documentNumber = profile['documentNumber']?.toString() ?? 'No registrado';
        final roles = (profile['roles'] as List?)?.whereType<String>().toSet().toList() ?? user.roles;
        final hasRole = (String role) => roles.any((item) => item.trim().toLowerCase() == role);
        final normalizedRoles = roles.map((item) => item.trim().toLowerCase()).toSet();
        final role = normalizedRoles.contains('jugador') || normalizedRoles.contains('player')
            ? 'jugador'
            : normalizedRoles.contains('entrenador') || normalizedRoles.contains('coach')
                ? 'entrenador'
                : normalizedRoles.contains('arbitro') || normalizedRoles.contains('referee') || normalizedRoles.contains('árbitro')
                    ? 'arbitro'
                    : normalizedRoles.contains('admin_liga')
                        ? 'admin_liga'
                        : normalizedRoles.contains('admin')
                            ? 'admin'
                            : (normalizedRoles.isNotEmpty ? normalizedRoles.first : 'jugador');
        final hasDocument = profile['documentNumber']?.toString().trim().isNotEmpty == true;
        final hasPlayerData = profile['shirtNumber'] != null &&
            int.tryParse(profile['shirtNumber'].toString()) != null &&
            profile['position']?.toString().trim().isNotEmpty == true;
        final hasRequiredProfileData = hasDocument && (role != 'jugador' || hasPlayerData);
        final completedByRole = (profile['profileCompletedByRole'] as Map?)?.map(
              (key, value) => MapEntry(key.toString().trim().toLowerCase(), value == true || value.toString().toLowerCase() == 'true'),
            ) ??
            const <String, bool>{};
        final profileCompleted = profile['profileCompleted'] == true ||
            profile['profileComplete'] == true ||
            profile['profileCompleted']?.toString().toLowerCase() == 'true' ||
            profile['profileComplete']?.toString().toLowerCase() == 'true' ||
            completedByRole[role] == true ||
            hasRequiredProfileData;
        final profileReadyToEvaluate = snapshot.connectionState == ConnectionState.active || snapshot.connectionState == ConnectionState.done;
        if (profileReadyToEvaluate && !snapshot.hasError && !profileCompleted) {
          return ProfileCompletionScreen(role: role);
        }
        return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      // La barra inferior se mantiene también en el perfil para que todos
      // los roles puedan regresar al home o consultar las demás secciones.
      bottomNavigationBar: AppBottomNavigationBar(
        selectedIndex: user?.roles.any((role) => role == 'admin' || role == 'admin_liga') == true ? 3 : 2,
        isAdmin: user?.roles.any((role) => role == 'admin' || role == 'admin_liga') == true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          CircleAvatar(
            radius: 42,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: Text(
              displayName.isEmpty ? '?' : displayName[0].toUpperCase(),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            displayName,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            email,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 32),
          Card(
            child: ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Nombre de la cuenta'),
              subtitle: Text(displayName),
            ),
          ),
          Card(child: ListTile(leading: const Icon(Icons.badge_outlined), title: const Text('Número de documento'), subtitle: Text(documentNumber))),
          Card(child: ListTile(leading: const Icon(Icons.email_outlined), title: const Text('Correo electrónico'), subtitle: Text(email))),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => context.go(RouteNames.recoverPassword),
            icon: const Icon(Icons.lock_reset_outlined),
            label: const Text('Cambiar contraseña'),
          ),
          if (hasRole('entrenador'))
            _roleButton(context, 'Ficha de entrenador', Icons.sports_outlined, () => _showRoleSheet(context, 'Ficha de entrenador', profile, ['teamName', 'specialty', 'experience'])),
          if (hasRole('arbitro') || hasRole('árbitro') || hasRole('referee'))
            _roleButton(context, 'Ficha de árbitro', Icons.sports_handball_outlined, () => _showRoleSheet(context, 'Ficha de árbitro', profile, ['category', 'experience', 'phone'])),
          if (hasRole('jugador'))
            _roleButton(context, 'Ficha de jugador', Icons.person_outline, () => _showRoleSheet(context, 'Ficha de jugador', profile, ['shirtNumber', 'position', 'teamName'])),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => context.read<AuthBloc>().add(
              const AuthLogoutRequested(),
            ),
            icon: const Icon(Icons.logout),
            label: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
      },
    );
  }

  Widget _roleButton(BuildContext context, String label, IconData icon, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: OutlinedButton.icon(onPressed: onPressed, icon: Icon(icon), label: Text(label)),
    );
  }

  void _showRoleSheet(BuildContext context, String title, Map<String, dynamic> profile, List<String> fields) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          shrinkWrap: true,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            for (final field in fields)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_fieldLabel(field)),
                subtitle: Text(profile[field]?.toString().trim().isNotEmpty == true ? profile[field].toString() : 'No registrado'),
              ),
          ],
        ),
      ),
    );
  }

  String _fieldLabel(String field) {
    const labels = {'teamName': 'Equipo', 'specialty': 'Especialidad', 'experience': 'Experiencia', 'category': 'Categoría', 'phone': 'Teléfono', 'shirtNumber': 'Número de camiseta', 'position': 'Posición'};
    return labels[field] ?? field;
  }

  String _displayName(AppUser? user) {
    final name = user?.displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final email = user?.email?.trim();
    if (email != null && email.isNotEmpty) return email.split('@').first;
    return 'Usuario HandPlay';
  }
}
