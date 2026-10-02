import 'package:dartz/dartz.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';
import '../models/app_user_model.dart';

/// ES: Convierte resultados y excepciones del datasource en valores Either del dominio.
/// EN: Converts datasource results and exceptions into domain-level Either values.
class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;

  /// ES: Crea el repositorio alrededor del datasource conectado a Firebase.
  /// EN: Creates the repository around its Firebase-backed datasource.
  const AuthRepositoryImpl(this.remoteDataSource);

  static const _unexpectedErrorMessage =
      'Ocurrió un error inesperado. Intenta de nuevo.';

  /// ES: Emite la sesión Firebase actual como usuario del dominio.
  /// EN: Streams the current Firebase session as a domain user.
  @override
  Stream<AppUser?> watchAuthState() {
    return remoteDataSource.authStateChanges.asyncMap((user) async {
      if (user == null) return null;
      return _appUserFromFirebaseUser(user);
    });
  }

  /// ES: Combina los roles del token Firebase con los guardados en el perfil.
  /// EN: Combines Firebase token claims and stored profile roles for a user.
  Future<AppUserModel> _appUserFromFirebaseUser(fb.User firebaseUser) async {
    final token = await firebaseUser.getIdTokenResult();
    final claimRoles = _rolesFromClaims(token.claims);
    final storedRoles = await remoteDataSource.rolesForUser(firebaseUser.uid);
    final roles = {...claimRoles, ...storedRoles};
    return AppUserModel.fromFirebaseUser(firebaseUser, roles: roles.isEmpty ? const ['jugador'] : roles.toList());
  }

  /// ES: Lee roles actuales y heredados y los normaliza en una lista.
  /// EN: Reads current and legacy role claims into a normalized role list.
  static List<String> _rolesFromClaims(Map<String, dynamic>? claims) {
    final rawRoles = claims?['roles'];
    if (rawRoles is List) {
      final roles = rawRoles.whereType<String>().toSet().toList();
      if (roles.isNotEmpty) return roles;
    }
    final legacyRole = claims?['rol'];
    return legacyRole is String ? [legacyRole] : const ['jugador'];
  }

  /// ES: Inicia sesión y convierte errores técnicos en fallos de autenticación.
  /// EN: Signs in and converts infrastructure errors into authentication failures.
  @override
  Future<Either<Failure, AppUser>> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    try {
      final user = await remoteDataSource.signInWithEmailPassword(
        email: email,
        password: password,
      );
      return Right(await _appUserFromFirebaseUser(user));
    } on ServerException catch (e) {
      return Left(AuthFailure(e.message));
    } catch (_) {
      return const Left(AuthFailure(_unexpectedErrorMessage));
    }
  }

  /// ES: Registra una cuenta y convierte errores técnicos en fallos.
  /// EN: Registers an account and converts infrastructure errors into failures.
  @override
  Future<Either<Failure, AppUser>> registerWithEmailPassword({
    required String name,
    required String documentNumber,
    required String email,
    required String password,
  }) async {
    try {
      final user = await remoteDataSource.registerWithEmailPassword(
        name: name,
        documentNumber: documentNumber,
        email: email,
        password: password,
      );
      return Right(await _appUserFromFirebaseUser(user));
    } on ServerException catch (e) {
      return Left(AuthFailure(e.message));
    } catch (_) {
      return const Left(AuthFailure(_unexpectedErrorMessage));
    }
  }

  /// ES: Inicia sesión con Google y devuelve un resultado del dominio.
  /// EN: Signs in with Google and returns a domain-level result.
  @override
  Future<Either<Failure, AppUser>> signInWithGoogle() async {
    try {
      final user = await remoteDataSource.signInWithGoogle();
      return Right(await _appUserFromFirebaseUser(user));
    } on ServerException catch (e) {
      return Left(AuthFailure(e.message));
    } catch (_) {
      return const Left(AuthFailure(_unexpectedErrorMessage));
    }
  }

  /// ES: Solicita un correo de recuperación y traduce errores del datasource.
  /// EN: Requests a reset email and maps datasource errors to failures.
  @override
  Future<Either<Failure, Unit>> sendPasswordResetEmail(String email) async {
    try {
      await remoteDataSource.sendPasswordResetEmail(email);
      return const Right(unit);
    } on ServerException catch (e) {
      return Left(AuthFailure(e.message));
    } catch (_) {
      return const Left(AuthFailure(_unexpectedErrorMessage));
    }
  }

  /// ES: Cierra la sesión e informa si la operación tuvo éxito.
  /// EN: Signs out and reports whether the operation succeeded.
  @override
  Future<Either<Failure, Unit>> signOut() async {
    try {
      await remoteDataSource.signOut();
      return const Right(unit);
    } catch (_) {
      return const Left(AuthFailure('No se pudo cerrar sesión. Intenta de nuevo.'));
    }
  }
}
