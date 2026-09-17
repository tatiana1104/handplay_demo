import 'package:equatable/equatable.dart';

/// Tipo base para errores de negocio/infraestructura que cruzan hacia
/// el dominio y el BLoC como `Either<Failure, T>` (patrón `dartz`).
/// Nunca contiene detalles de Firebase/HTTP — solo un mensaje ya listo
/// para mostrarse al usuario.
abstract class Failure extends Equatable {
  final String message;
  const Failure(this.message);

  @override
  List<Object?> get props => [message];
}

/// Falla proveniente de autenticación (Firebase Auth / Google Sign-In).
class AuthFailure extends Failure {
  const AuthFailure(super.message);
}
