import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/app_user.dart';
import '../repositories/auth_repository.dart';

/// ES: Coordina el inicio de sesión por correo a través del repositorio.
/// EN: Coordinates email/password sign-in through the domain repository.
class SignInWithEmailPassword {
  final AuthRepository repository;
  /// ES: Crea el caso de uso con el repositorio de autenticación.
  /// EN: Creates this use case with its authentication repository.
  const SignInWithEmailPassword(this.repository);

  /// ES: Solicita el acceso y devuelve un fallo o el usuario autenticado.
  /// EN: Requests sign-in and returns a failure or the authenticated user.
  Future<Either<Failure, AppUser>> call({
    required String email,
    required String password,
  }) {
    return repository.signInWithEmailPassword(email: email, password: password);
  }
}
