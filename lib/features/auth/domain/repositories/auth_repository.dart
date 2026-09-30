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

  /// ES: Autentica con correo electrónico y contraseña.
  /// EN: Authenticates with an email and password.
  Future<Either<Failure, AppUser>> signInWithEmailPassword({
    required String email,
    required String password,
  });

  /// ES: Crea una cuenta y devuelve su usuario de dominio.
  /// EN: Creates an account and returns its domain user.
  Future<Either<Failure, AppUser>> registerWithEmailPassword({
    required String name,
    required String email,
    required String password,
  });

  /// ES: Autentica mediante la cuenta de Google.
  /// EN: Authenticates with the Google identity provider.
  Future<Either<Failure, AppUser>> signInWithGoogle();

  /// ES: Envía un correo para restablecer la contraseña.
  /// EN: Sends a password-reset email to the supplied address.
  Future<Either<Failure, Unit>> sendPasswordResetEmail(String email);

  /// ES: Cierra la sesión autenticada actual.
  /// EN: Ends the current authenticated session.
  Future<Either<Failure, Unit>> signOut();
}
