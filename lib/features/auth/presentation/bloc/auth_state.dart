import 'package:equatable/equatable.dart';

import '../../domain/entities/app_user.dart';

/// ES: Tipo base para los estados de autenticación expuestos a la interfaz.
/// EN: Base type for authentication states exposed to the UI.
abstract class AuthState extends Equatable {
  const AuthState();

  /// ES: Expone los datos del estado para compararlos por valor.
  /// EN: Exposes state data for value-based equality.
  @override
  List<Object?> get props => [];
}

/// Estado antes de que Firebase resuelva si hay una sesión activa
/// (arranque en frío). El router NO debe redirigir todavía en este
/// estado — ver la función `redirect` en `main.dart`.
/// ES: La autenticación aún no ha resuelto la sesión Firebase actual.
/// EN: Authentication has not yet resolved the current Firebase session.
class AuthInitial extends AuthState {
  /// ES: Crea el estado inicial.
  /// EN: Creates the initial state.
  const AuthInitial();
}

/// Una operación de auth (login, registro, Google, reset) está en
/// curso. La UI debe deshabilitar los formularios mientras esto dure.
class AuthLoading extends AuthState {
  /// ES: Crea el estado que indica una operación en curso.
  /// EN: Creates a state marking an authentication operation in progress.
  const AuthLoading();
}

/// ES: Hay un usuario autenticado en Firebase.
/// EN: A Firebase user is currently authenticated.
class AuthAuthenticated extends AuthState {
  final AppUser user;
  /// ES: Crea el estado autenticado para el usuario indicado.
  /// EN: Creates the authenticated state for the given user.
  const AuthAuthenticated(this.user);

  /// ES: Usa el usuario como dato de igualdad de este estado.
  /// EN: Uses the user as this state's equality data.
  @override
  List<Object?> get props => [user];
}

/// ES: No hay un usuario autenticado actualmente.
/// EN: No user is currently authenticated.
class AuthUnauthenticated extends AuthState {
  /// ES: Crea el estado de sesión cerrada.
  /// EN: Creates the signed-out state.
  const AuthUnauthenticated();
}

/// Falla de una operación puntual (login/registro/Google/reset). El
/// listener de `authStateChanges` sigue siendo la única fuente de
/// verdad sobre si hay sesión o no — por ejemplo, si falla un reset de
/// contraseña estando ya logueado, este estado no implica ningún
/// logout.
class AuthFailure extends AuthState {
  final String message;
  /// ES: Crea un estado de error con su mensaje para mostrar.
  /// EN: Creates a state for an operation error and its display message.
  const AuthFailure(this.message);

  /// ES: Usa el mensaje de error como dato de igualdad del estado.
  /// EN: Uses the error message as this state's equality data.
  @override
  List<Object?> get props => [message];
}

/// Confirmación puntual de que el correo de recuperación se envió.
class AuthPasswordResetEmailSent extends AuthState {
  /// ES: Crea el estado que confirma el envío del correo de recuperación.
  /// EN: Creates the confirmation state for a sent password-reset email.
  const AuthPasswordResetEmailSent();
}
