import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/app_user.dart';
import '../repositories/auth_repository.dart';

/// ES: Coordina el inicio de sesión con Google mediante el repositorio.
/// EN: Coordinates Google sign-in through the domain repository.
class SignInWithGoogle {
  final AuthRepository repository;
  /// ES: Crea el caso de uso con el repositorio de autenticación.
  /// EN: Creates this use case with its authentication repository.
  const SignInWithGoogle(this.repository);

  /// ES: Solicita acceso con Google y devuelve el usuario o un fallo.
  /// EN: Requests Google sign-in and returns the user or a failure.
  Future<Either<Failure, AppUser>> call() => repository.signInWithGoogle();
}
