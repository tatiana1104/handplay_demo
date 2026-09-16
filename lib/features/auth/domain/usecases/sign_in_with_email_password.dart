import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/app_user.dart';
import '../repositories/auth_repository.dart';

class SignInWithEmailPassword {
  final AuthRepository repository;
  const SignInWithEmailPassword(this.repository);

  Future<Either<Failure, AppUser>> call({
    required String email,
    required String password,
  }) {
    return repository.signInWithEmailPassword(email: email, password: password);
  }
}
