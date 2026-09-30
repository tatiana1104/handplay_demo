import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../repositories/auth_repository.dart';

/// ES: Coordina el cierre de sesión mediante el repositorio.
/// EN: Coordinates ending the authenticated session through the repository.
class SignOut {
  final AuthRepository repository;
  /// ES: Crea el caso de uso con el repositorio de autenticación.
  /// EN: Creates this use case with its authentication repository.
  const SignOut(this.repository);

  /// ES: Cierra la sesión y devuelve un fallo o un resultado exitoso.
  /// EN: Signs out and returns a failure or a successful result.
  Future<Either<Failure, Unit>> call() => repository.signOut();
}
