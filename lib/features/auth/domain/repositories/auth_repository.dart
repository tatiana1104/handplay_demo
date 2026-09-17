import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/app_user.dart';

/// Contrato de autenticación que expone el dominio. La UI y el BLoC
/// solo conocen esta interfaz — nunca `AuthRepositoryImpl` ni
/// `AuthRemoteDataSource` directamente (esos son detalles de
/// infraestructura, capa `data`).
abstract class AuthRepository {
  /// Emite el usuario autenticado actual, o `null` si no hay sesión.
  /// Es la única fuente de verdad sobre el estado de sesión de la app
  /// (el `AuthBloc` se suscribe a este stream).
  Stream<AppUser?> watchAuthState();

  Future<Either<Failure, AppUser>> signInWithEmailPassword({
    required String email,
    required String password,
  });

  Future<Either<Failure, AppUser>> registerWithEmailPassword({
    required String name,
    required String email,
    required String password,
  });

  Future<Either<Failure, AppUser>> signInWithGoogle();

  Future<Either<Failure, Unit>> sendPasswordResetEmail(String email);

  Future<Either<Failure, Unit>> signOut();
}
