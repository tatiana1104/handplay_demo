import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../repositories/auth_repository.dart';

/// ES: Coordina la recuperación de contraseña mediante el repositorio.
/// EN: Coordinates password recovery through the domain repository.
class SendPasswordResetEmail {
  final AuthRepository repository;
  /// ES: Crea el caso de uso con el repositorio de autenticación.
  /// EN: Creates this use case with its authentication repository.
  const SendPasswordResetEmail(this.repository);

  /// ES: Solicita un correo de restablecimiento para la dirección indicada.
  /// EN: Requests a password-reset email for the supplied address.
  Future<Either<Failure, Unit>> call(String email) {
    return repository.sendPasswordResetEmail(email);
  }
}
