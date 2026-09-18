import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import '../../domain/entities/app_user.dart';
import '../../../../shared/widgets/app_bottom_navigation_bar.dart';

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
          Card(
            child: ListTile(
              leading: const Icon(Icons.admin_panel_settings_outlined),
              title: const Text('Tipo de cuenta'),
              subtitle: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(FirebaseAuth.instance.currentUser?.uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  final firestoreRoles = (snapshot.data?.data()?['roles'] as List?)
                      ?.whereType<String>()
                      .toSet()
                      .toList();
                  final roles = firestoreRoles == null || firestoreRoles.isEmpty
                      ? user?.roles ?? const ['jugador']
                      : firestoreRoles;
                  return Text(roles.map(_roleLabel).join(', '));
                },
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.email_outlined),
              title: const Text('Correo electrónico'),
              subtitle: Text(email),
            ),
          ),
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
  }

  String _displayName(AppUser? user) {
    final name = user?.displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final email = user?.email?.trim();
    if (email != null && email.isNotEmpty) return email.split('@').first;
    return 'Usuario HandPlay';
  }
}
