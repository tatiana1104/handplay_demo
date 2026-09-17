import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/register_with_email_password.dart';
import '../../domain/usecases/send_password_reset_email.dart';
import '../../domain/usecases/sign_in_with_email_password.dart';
import '../../domain/usecases/sign_in_with_google.dart';
import '../../domain/usecases/sign_out.dart';
import 'auth_event.dart';
import 'auth_state.dart';

/// BLoC central de autenticación de HandPlay.
///
/// Es un singleton (ver `core/di/injection_container.dart`): vive
/// durante toda la sesión de la app porque mantiene una suscripción
/// activa al stream `authStateChanges` de Firebase, que es la única
/// fuente de verdad sobre si hay un usuario logueado. El `GoRouter` de
/// `main.dart` escucha este bloc (vía `GoRouterRefreshStream`) para
/// decidir a qué pantalla redirigir en cada cambio de estado.
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final SignInWithEmailPassword _signIn;
  final RegisterWithEmailPassword _register;
  final SignInWithGoogle _signInWithGoogle;
  final SendPasswordResetEmail _sendPasswordResetEmail;
  final SignOut _signOut;
  final AuthRepository _authRepository;

  StreamSubscription<AppUser?>? _authStateSubscription;

  AuthBloc({
    required SignInWithEmailPassword signIn,
    required RegisterWithEmailPassword register,
    required SignInWithGoogle signInWithGoogle,
    required SendPasswordResetEmail sendPasswordResetEmail,
    required SignOut signOut,
    required AuthRepository authRepository,
  })  : _signIn = signIn,
        _register = register,
        _signInWithGoogle = signInWithGoogle,
        _sendPasswordResetEmail = sendPasswordResetEmail,
        _signOut = signOut,
        _authRepository = authRepository,
        super(const AuthInitial()) {
    on<AuthUserChanged>(_onUserChanged);
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthRegisterRequested>(_onRegisterRequested);
    on<AuthGoogleSignInRequested>(_onGoogleSignInRequested);
    on<AuthPasswordResetRequested>(_onPasswordResetRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);

    _authStateSubscription = _authRepository.watchAuthState().listen(
          (user) => add(AuthUserChanged(user)),
        );
  }

  void _onUserChanged(AuthUserChanged event, Emitter<AuthState> emit) {
    if (event.user != null) {
      emit(AuthAuthenticated(event.user!));
    } else {
      emit(const AuthUnauthenticated());
    }
  }

  Future<void> _onLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    final result = await _signIn(email: event.email, password: event.password);
    result.fold(
      (failure) => emit(AuthFailure(failure.message)),
      (user) => emit(AuthAuthenticated(user)),
    );
  }

  Future<void> _onRegisterRequested(
    AuthRegisterRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    final result = await _register(
      name: event.name,
      email: event.email,
      password: event.password,
    );
    result.fold(
      (failure) => emit(AuthFailure(failure.message)),
      (user) => emit(AuthAuthenticated(user)),
    );
  }

  Future<void> _onGoogleSignInRequested(
    AuthGoogleSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    final result = await _signInWithGoogle();
    result.fold(
      (failure) => emit(AuthFailure(failure.message)),
      (user) => emit(AuthAuthenticated(user)),
    );
  }

  Future<void> _onPasswordResetRequested(
    AuthPasswordResetRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    final result = await _sendPasswordResetEmail(event.email);
    result.fold(
      (failure) => emit(AuthFailure(failure.message)),
      (_) => emit(const AuthPasswordResetEmailSent()),
    );
  }

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    // No emitimos nada acá a propósito: el listener de
    // `watchAuthState` va a recibir `null` en cuanto Firebase confirme
    // el signOut, y eso dispara `AuthUserChanged(null)` ->
    // `AuthUnauthenticated` por el camino normal.
    await _signOut();
  }

  @override
  Future<void> close() {
    _authStateSubscription?.cancel();
    return super.close();
  }
}
