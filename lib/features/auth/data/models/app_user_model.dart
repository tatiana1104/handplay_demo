import 'package:firebase_auth/firebase_auth.dart' as fb;

import '../../domain/entities/app_user.dart';

/// Adaptador entre el `User` de `firebase_auth` (detalle de
/// infraestructura) y la entidad de dominio `AppUser`. Es el único
/// lugar del código, fuera de la capa `data`, que debería "conocer"
/// que detrás hay un `fb.User`.
class AppUserModel extends AppUser {
  /// ES: Crea un modelo de usuario Firebase compatible con el dominio.
  /// EN: Creates a Firebase-backed user model with domain-compatible fields.
  const AppUserModel({
    required super.uid,
    super.email,
    super.displayName,
    super.photoUrl,
    super.roles = const ['jugador'],
  });

  /// ES: Convierte un usuario Firebase Auth y sus roles al modelo de dominio.
  /// EN: Maps a Firebase Auth user and its roles into the domain model.
  factory AppUserModel.fromFirebaseUser(
    fb.User user, {
    List<String> roles = const ['jugador'],
  }) {
    return AppUserModel(
      uid: user.uid,
      email: user.email,
      displayName: user.displayName,
      photoUrl: user.photoURL,
      roles: roles,
    );
  }
}
