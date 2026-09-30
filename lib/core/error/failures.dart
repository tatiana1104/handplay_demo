import 'package:equatable/equatable.dart';

/// Tipo base para errores de negocio/infraestructura que cruzan hacia
/// el dominio y el BLoC como `Either<Failure, T>` (patrón `dartz`).
/// Nunca contiene detalles de Firebase/HTTP — solo un mensaje ya listo
/// para mostrarse al usuario.
abstract class Failure extends Equatable {
  final String message;
  /// ES: Crea un fallo con el mensaje que se mostrará al usuario.
  /// EN: Creates a failure with its user-facing message.
  const Failure(this.message);

  /// ES: Usa el mensaje para comparar fallos por valor.
  /// EN: Uses the message as the failure's value-equality data.
  @override
  List<Object?> get props => [message];
}

/// Falla proveniente de autenticación (Firebase Auth / Google Sign-In).
class AuthFailure extends Failure {
  /// ES: Crea un fallo de autenticación.
  /// EN: Creates an authentication failure.
  const AuthFailure(super.message);
}
