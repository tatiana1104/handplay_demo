import 'package:equatable/equatable.dart';

import '../../domain/entities/app_user.dart';

/// ES: Tipo base de las acciones de autenticación procesadas por AuthBloc.
/// EN: Base type for authentication actions handled by AuthBloc.
abstract class AuthEvent extends Equatable {
  const AuthEvent();

  /// ES: Expone los datos para comparar eventos por valor en pruebas.
  /// EN: Exposes event data so BLoC tests can compare events by value.
  @override
  List<Object?> get props => [];
}

/// Evento interno: se dispara cada vez que Firebase notifica un cambio
/// de sesión (login, logout, refresh de token). La UI nunca lo
/// despacha directamente — lo dispara el propio `AuthBloc` al
/// suscribirse a `AuthRepository.watchAuthState()`.
class AuthUserChanged extends AuthEvent {
  final AppUser? user;
  const AuthUserChanged(this.user);

  @override
  List<Object?> get props => [user];
}

/// ES: Solicita autenticación con correo y contraseña.
/// EN: Requests email/password authentication.
class AuthLoginRequested extends AuthEvent {
  final String email;
  final String password;
  /// ES: Crea la solicitud de acceso con las credenciales indicadas.
  /// EN: Creates a login request containing the submitted credentials.
  const AuthLoginRequested({required this.email, required this.password});

  /// ES: Usa las credenciales como datos de igualdad del evento.
  /// EN: Provides the credentials as the event's equality data.
  @override
  List<Object?> get props => [email, password];
}

/// ES: Solicita crear una cuenta nueva con correo y contraseña.
/// EN: Requests creation of a new email/password account.
class AuthRegisterRequested extends AuthEvent {
  final String name;
  final String email;
  final String password;
  /// ES: Crea la solicitud de cuenta con los datos del perfil.
  /// EN: Creates an account request with the submitted profile details.
  const AuthRegisterRequested({
    required this.name,
    required this.email,
    required this.password,
  });

  /// ES: Usa los campos de registro para comparar eventos por valor.
  /// EN: Uses the registration fields as the event's equality data.
  @override
  List<Object?> get props => [name, email, password];
}

/// ES: Solicita autenticación mediante Google Sign-In.
/// EN: Requests authentication through Google Sign-In.
class AuthGoogleSignInRequested extends AuthEvent {
  /// ES: Crea una solicitud de autenticación con Google.
  /// EN: Creates a Google authentication request.
  const AuthGoogleSignInRequested();
}

/// ES: Solicita enviar un correo de recuperación de contraseña.
/// EN: Requests a password-recovery email.
class AuthPasswordResetRequested extends AuthEvent {
  final String email;
  /// ES: Crea la solicitud de recuperación para el correo indicado.
  /// EN: Creates a recovery request for the supplied email.
  const AuthPasswordResetRequested(this.email);

  /// ES: Usa el correo como dato de igualdad del evento.
  /// EN: Provides the email as the event's equality data.
  @override
  List<Object?> get props => [email];
}

/// ES: Solicita cerrar la sesión actual.
/// EN: Requests termination of the current session.
class AuthLogoutRequested extends AuthEvent {
  /// ES: Crea una solicitud de cierre de sesión.
  /// EN: Creates a logout request.
  const AuthLogoutRequested();
}
