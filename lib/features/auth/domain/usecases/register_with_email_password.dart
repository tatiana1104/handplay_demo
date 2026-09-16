import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/app_user.dart';
import '../repositories/auth_repository.dart';

class RegisterWithEmailPassword {
  final AuthRepository repository;
  const RegisterWithEmailPassword(this.repository);

  Future<Either<Failure, AppUser>> call({
    required String name,
    required String email,
    required String password,
  }) {
    return repository.registerWithEmailPassword(
      name: name,
      email: email,
      password: password,
    );
  }
}
