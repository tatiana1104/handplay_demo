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

  /// ES: Crea un usuario inmutable e independiente de los tipos de Firebase.
  /// EN: Creates an immutable user independent of Firebase types.
  const AppUser({
    required this.uid,
    this.email,
    this.displayName,
    this.photoUrl,
    this.roles = const ['jugador'],
  });

  /// ES: Comprueba si el usuario tiene el rol indicado.
  /// EN: Checks whether this user has the requested application role.
  bool hasRole(String role) => roles.contains(role);

  /// ES: Indica si este usuario puede administrar la liga.
  /// EN: Reports whether this user can administer the league.
  bool get isAdmin => hasRole('admin') || hasRole('admin_liga');

  /// ES: Expone los campos usados para comparar usuarios del dominio.
  /// EN: Exposes the fields used to compare two domain users.
  @override
  List<Object?> get props => [uid, email, displayName, photoUrl, roles];
}
