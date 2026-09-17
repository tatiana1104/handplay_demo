import 'package:equatable/equatable.dart';

/// Representación de dominio de un usuario autenticado en HandPlay.
///
/// Deliberadamente NO incluye campos específicos de Firebase (ej.
/// `providerId`, `metadata`): esta clase es la que usan el BLoC y la
/// UI, y no debería depender de ningún detalle de infraestructura.
/// El perfil completo del usuario (roles, número de documento, etc. —
/// ver entidad USUARIO en el Anexo B del PRD) vive en Firestore y se
/// modelará en un sprint posterior, cuando se implemente el feature de
/// perfil/roles.
class AppUser extends Equatable {
  final String uid;
  final String? email;
  final String? displayName;
  final String? photoUrl;
  final List<String> roles;

  const AppUser({
    required this.uid,
    this.email,
    this.displayName,
    this.photoUrl,
    this.roles = const ['jugador'],
  });

  bool hasRole(String role) => roles.contains(role);

  bool get isAdmin => hasRole('admin') || hasRole('admin_liga');

  @override
  List<Object?> get props => [uid, email, displayName, photoUrl, roles];
}
