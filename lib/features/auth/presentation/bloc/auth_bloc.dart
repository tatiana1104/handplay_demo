import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Estados que utiliza el router para decidir si una ruta requiere sesión.
enum AuthStatus { unknown, unauthenticated, authenticated }

class AuthState extends Equatable {
  const AuthState({
    required this.status,
    this.user,
    this.role,
  });

  const AuthState.unknown() : this(status: AuthStatus.unknown);

  final AuthStatus status;
  final User? user;
  final String? role;

  bool get isAuthenticated => status == AuthStatus.authenticated;

  AuthState copyWith({
    AuthStatus? status,
    User? user,
    String? role,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      role: role ?? this.role,
    );
  }

  @override
  List<Object?> get props => [status, user?.uid, role];
}

/// Escucha Firebase Auth y expone un estado estable para go_router.
class AuthBloc extends Cubit<AuthState> {
  AuthBloc({FirebaseAuth? auth})
      : _auth = auth ?? FirebaseAuth.instance,
        super(const AuthState.unknown()) {
    _subscription = _auth.authStateChanges().listen(_onUserChanged);
  }

  final FirebaseAuth _auth;
  late final StreamSubscription<User?> _subscription;

  Future<void> _onUserChanged(User? user) async {
    if (user == null) {
      emit(const AuthState(status: AuthStatus.unauthenticated));
      return;
    }

    final token = await user.getIdTokenResult();
    final claims = token.claims ?? <String, dynamic>{};
    emit(AuthState(
      status: AuthStatus.authenticated,
      user: user,
      role: claims['role'] as String?,
    ));
  }

  Future<void> signOut() => _auth.signOut();

  @override
  Future<void> close() async {
    await _subscription.cancel();
    return super.close();
  }
}
