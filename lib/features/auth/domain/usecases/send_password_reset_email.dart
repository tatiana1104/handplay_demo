import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../repositories/auth_repository.dart';

class SendPasswordResetEmail {
  final AuthRepository repository;
  const SendPasswordResetEmail(this.repository);

  Future<Either<Failure, Unit>> call(String email) {
    return repository.sendPasswordResetEmail(email);
  }
}
