import 'package:equatable/equatable.dart';

import '../../domain/entities/app_user.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

/// Estado antes de que Firebase resuelva si hay una sesión activa
/// (arranque en frío). El router NO debe redirigir todavía en este
/// estado — ver la función `redirect` en `main.dart`.
class AuthInitial extends AuthState {
  const AuthInitial();
}

/// Una operación de auth (login, registro, Google, reset) está en
/// curso. La UI debe deshabilitar los formularios mientras esto dure.
class AuthLoading extends AuthState {
  const AuthLoading();
}

class AuthAuthenticated extends AuthState {
  final AppUser user;
  const AuthAuthenticated(this.user);

  @override
  List<Object?> get props => [user];
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

/// Falla de una operación puntual (login/registro/Google/reset). El
/// listener de `authStateChanges` sigue siendo la única fuente de
/// verdad sobre si hay sesión o no — por ejemplo, si falla un reset de
/// contraseña estando ya logueado, este estado no implica ningún
/// logout.
class AuthFailure extends AuthState {
  final String message;
  const AuthFailure(this.message);

  @override
  List<Object?> get props => [message];
}

/// Confirmación puntual de que el correo de recuperación se envió.
class AuthPasswordResetEmailSent extends AuthState {
  const AuthPasswordResetEmailSent();
}
