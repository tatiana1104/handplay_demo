import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/app_user.dart';
import '../repositories/auth_repository.dart';

/// ES: Coordina el registro por correo mediante el repositorio.
/// EN: Coordinates email/password account creation through the repository.
class RegisterWithEmailPassword {
  final AuthRepository repository;
  /// ES: Crea el caso de uso con el repositorio de autenticación.
  /// EN: Creates this use case with its authentication repository.
  const RegisterWithEmailPassword(this.repository);

  /// ES: Registra la cuenta y devuelve un fallo o el usuario creado.
  /// EN: Registers the account and returns a failure or its user.
  Future<Either<Failure, AppUser>> call({
    required String name,
    required String documentNumber,
    required String email,
    required String password,
  }) {
    return repository.registerWithEmailPassword(
      name: name,
      documentNumber: documentNumber,
      email: email,
      password: password,
    );
  }
}
