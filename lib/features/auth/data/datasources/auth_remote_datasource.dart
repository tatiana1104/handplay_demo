import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:google_sign_in/google_sign_in.dart';

import '../../../../core/error/exceptions.dart';
import 'auth_error_mapper.dart';

/// Capa de infraestructura: única clase del feature de auth que habla
/// directamente con los SDKs de Firebase Auth y Google Sign-In. El
/// resto de la app (BLoC, UI) nunca importa `firebase_auth` ni
/// `google_sign_in` directamente — siempre pasa por
/// `AuthRepository`/`AuthRepositoryImpl`.
class AuthRemoteDataSource {
  final fb.FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;

  bool _googleInitialized = false;

  AuthRemoteDataSource({
    fb.FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
  })  : _firebaseAuth = firebaseAuth ?? fb.FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  Stream<fb.User?> get authStateChanges => _firebaseAuth.authStateChanges();

  Future<fb.User> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        throw const ServerException('No se pudo iniciar sesión.');
      }
      return user;
    } on fb.FirebaseAuthException catch (e) {
      throw ServerException(mapFirebaseAuthError(e.code));
    }
  }

  Future<fb.User> registerWithEmailPassword({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      var user = credential.user;
      if (user == null) {
        throw const ServerException('No se pudo crear la cuenta.');
      }
      // El nombre no se puede fijar en `createUserWithEmailAndPassword`,
      // así que se actualiza aparte y se recarga el usuario para que el
      // `displayName` quede disponible de inmediato en el resto de la app.
      await user.updateDisplayName(name.trim());
      await user.reload();
      user = _firebaseAuth.currentUser ?? user;
      unawaited(_ensureUserProfile(user, name: name.trim()));
      return user;
    } on fb.FirebaseAuthException catch (e) {
      throw ServerException(mapFirebaseAuthError(e.code));
    }
  }

  /// Flujo de Google Sign-In con la API de `google_sign_in` ^7, que
  /// separa autenticación (identidad) de autorización (permisos/scopes).
  /// `GoogleSignIn.instance.initialize()` debe haberse llamado antes,
  /// una sola vez, al arrancar la app (ver `main.dart`).
  Future<fb.User> signInWithGoogle() async {
    // `initialize()` debe llamarse una sola vez antes de `authenticate()`.
    // Se hace acá, perezosamente (y no en `main()`), porque es exactamente
    // como ya estaba probado que funciona en este proyecto antes de esta
    // migración a BLoC.
    if (!_googleInitialized) {
      await _googleSignIn.initialize();
      _googleInitialized = true;
    }

    late final GoogleSignInAccount googleUser;
    try {
      googleUser = await _googleSignIn.authenticate(scopeHint: const ['email']);
    } catch (_) {
      throw const ServerException(
        'No se pudo completar el inicio de sesión con Google. Intenta de nuevo.',
      );
    }

    final idToken = googleUser.authentication.idToken;
    if (idToken == null) {
      throw const ServerException(
        'Google no devolvió un token válido. Intenta de nuevo.',
      );
    }

    // El accessToken es opcional para autenticar con Firebase (el
    // idToken alcanza), pero se intenta obtener igual por si más
    // adelante se necesita para llamar APIs de Google a nombre del
    // usuario. Si falla, seguimos solo con el idToken.
    String? accessToken;
    try {
      final authorization =
          await googleUser.authorizationClient.authorizationForScopes(const ['email']);
      accessToken = authorization?.accessToken;
    } catch (_) {
      accessToken = null;
    }

    try {
      final credential = fb.GoogleAuthProvider.credential(
        idToken: idToken,
        accessToken: accessToken,
      );
      final userCredential = await _firebaseAuth.signInWithCredential(credential);
      final user = userCredential.user;
      if (user == null) {
        throw const ServerException('No se pudo iniciar sesión con Google.');
      }
      unawaited(_ensureUserProfile(user));
      return user;
    } on fb.FirebaseAuthException catch (e) {
      throw ServerException(mapFirebaseAuthError(e.code));
    }
  }

  Future<void> _ensureUserProfile(fb.User user, {String? name}) async {
    final users = FirebaseFirestore.instance.collection('users');
    final ref = users.doc(user.uid);
    final existing = await ref.get().timeout(const Duration(seconds: 5));
    final data = existing.data();
    final email = user.email?.trim().toLowerCase();
    Map<String, dynamic>? pendingData;
    DocumentReference<Map<String, dynamic>>? pendingRef;
    if (email != null && email.isNotEmpty) {
      final pending = await users.where('email', isEqualTo: email).limit(5).get();
      for (final candidate in pending.docs) {
        if (candidate.id != user.uid && candidate.data()['roles'] is List) {
          final roles = (candidate.data()['roles'] as List).map((value) => value.toString().toLowerCase()).toList();
          if (roles.contains('arbitro') || roles.contains('entrenador') || roles.contains('jugador') || roles.contains('player')) {
            pendingRef = candidate.reference;
            pendingData = candidate.data();
            break;
          }
        }
      }
    }
    final mergedData = {...?pendingData, ...?data};
    final existingRoles = (mergedData['roles'] as List?)?.map((value) => value.toString()).toList();
    final isCoach = existingRoles?.contains('entrenador') == true || existingRoles?.contains('coach') == true;
    final isPlayer = existingRoles?.contains('jugador') == true || existingRoles?.contains('player') == true;
    final roles = {
      ...?existingRoles,
      if (!isCoach && (existingRoles == null || existingRoles.isEmpty)) 'jugador',
    };
    await ref.set({
      'uid': user.uid,
      'email': user.email,
      'nombre': name?.isNotEmpty == true ? name : (mergedData['nombre'] ?? user.displayName ?? ''),
      'roles': roles.toList(),
      'rol': mergedData['rol'] ?? (isCoach ? 'entrenador' : (isPlayer ? 'jugador' : 'jugador')),
      if (mergedData['displayName'] != null) 'displayName': mergedData['displayName'],
      if (mergedData['document'] != null) 'document': mergedData['document'],
      if (mergedData['accreditation'] != null) 'accreditation': mergedData['accreditation'],
      if (mergedData['nivel'] != null) 'nivel': mergedData['nivel'],
      'updatedAt': FieldValue.serverTimestamp(),
      if (!existing.exists) 'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    if (pendingRef != null) {
      await pendingRef.update({
        'linkedUid': user.uid,
        'linkedAt': FieldValue.serverTimestamp(),
        'roles': FieldValue.arrayRemove(['arbitro', 'entrenador', 'coach', 'jugador', 'player']),
      });
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email.trim());
    } on fb.FirebaseAuthException catch (e) {
      throw ServerException(mapFirebaseAuthError(e.code));
    }
  }

  Future<void> signOut() async {
    await _firebaseAuth.signOut();
    try {
      await _googleSignIn.signOut();
    } catch (_) {
      // Si la sesión no se había iniciado con Google, esto puede fallar
      // sin consecuencias: el signOut de Firebase ya es lo que importa
      // para cerrar la sesión de la app.
    }
  }
}
