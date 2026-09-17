import 'package:firebase_auth/firebase_auth.dart' as fb;

import '../../domain/entities/app_user.dart';

/// Adaptador entre el `User` de `firebase_auth` (detalle de
/// infraestructura) y la entidad de dominio `AppUser`. Es el único
/// lugar del código, fuera de la capa `data`, que debería "conocer"
/// que detrás hay un `fb.User`.
class AppUserModel extends AppUser {
  const AppUserModel({
    required super.uid,
    super.email,
    super.displayName,
    super.photoUrl,
    super.role = 'jugador',
  });

  factory AppUserModel.fromFirebaseUser(fb.User user) {
    return AppUserModel(
      uid: user.uid,
      email: user.email,
      displayName: user.displayName,
      photoUrl: user.photoURL,
      role: 'jugador',
    );
  }
}
