import 'package:dartz/dartz.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';
import '../models/app_user_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;

  const AuthRepositoryImpl(this.remoteDataSource);

  static const _unexpectedErrorMessage =
      'Ocurrió un error inesperado. Intenta de nuevo.';

  @override
  Stream<AppUser?> watchAuthState() {
    return remoteDataSource.authStateChanges.asyncMap((user) async {
      if (user == null) return null;
      return _appUserFromFirebaseUser(user);
    });
  }

  Future<AppUserModel> _appUserFromFirebaseUser(fb.User firebaseUser) async {
    final token = await firebaseUser.getIdTokenResult();
    final claimRoles = _rolesFromClaims(token.claims);
    final roles = claimRoles;
    return AppUserModel.fromFirebaseUser(firebaseUser, roles: roles.isEmpty ? const ['jugador'] : roles);
  }

  static List<String> _rolesFromClaims(Map<String, dynamic>? claims) {
    final rawRoles = claims?['roles'];
    if (rawRoles is List) {
      final roles = rawRoles.whereType<String>().toSet().toList();
      if (roles.isNotEmpty) return roles;
    }
    final legacyRole = claims?['rol'];
    return legacyRole is String ? [legacyRole] : const ['jugador'];
  }

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

  @override
  Future<Either<Failure, AppUser>> registerWithEmailPassword({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final user = await remoteDataSource.registerWithEmailPassword(
        name: name,
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
