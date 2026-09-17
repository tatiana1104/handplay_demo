import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/app_user.dart';
import '../repositories/auth_repository.dart';

class SignInWithGoogle {
  final AuthRepository repository;
  const SignInWithGoogle(this.repository);

  Future<Either<Failure, AppUser>> call() => repository.signInWithGoogle();
}
