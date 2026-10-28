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

  /// ES: Crea el datasource con clientes Firebase y Google inyectables.
  /// EN: Creates the datasource with injectable Firebase and Google clients.
  AuthRemoteDataSource({
    fb.FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
  })  : _firebaseAuth = firebaseAuth ?? fb.FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  /// ES: Expone al repositorio los cambios de sesión de Firebase.
  /// EN: Exposes Firebase session changes to the repository.
  Stream<fb.User?> get authStateChanges => _firebaseAuth.authStateChanges();

  /// ES: Lee los roles del usuario guardados en Firestore.
  /// EN: Reads the user's stored Firestore roles.
  Future<List<String>> rolesForUser(String uid) async {
    final data = (await FirebaseFirestore.instance.collection('users').doc(uid).get()).data();
    final roles = (data?['roles'] as List?)
            ?.map((value) => value.toString().trim().toLowerCase())
            .where((value) => value.isNotEmpty)
            .toSet() ??
        <String>{};
    return roles.toList();
  }

  /// ES: Inicia sesión con Firebase y traduce errores del SDK a excepciones del dominio.
  /// EN: Signs in through Firebase and maps SDK errors to domain exceptions.
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

  /// ES: Crea la cuenta Firebase, asigna el nombre y asegura su perfil.
  /// EN: Creates a Firebase account, sets its name, and ensures its profile exists.
  Future<fb.User> registerWithEmailPassword({
    required String name,
    required String documentNumber,
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
      unawaited(_ensureUserProfile(
        user,
        name: name.trim(),
        documentNumber: documentNumber.trim(),
      ));
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
      await _ensureUserProfile(user);
      return user;
    } on fb.FirebaseAuthException catch (e) {
      throw ServerException(mapFirebaseAuthError(e.code));
    }
  }

  /// ES: Crea o repara perfiles Firestore después de entrar con Google.
  /// EN: Creates or repairs Firestore profiles after a Google sign-in.
  Future<void> _ensureUserProfile(
    fb.User user, {
    String? name,
    String? documentNumber,
  }) async {
    final users = FirebaseFirestore.instance.collection('users');
    final ref = users.doc(user.uid);
    final existing = await ref.get().timeout(const Duration(seconds: 5));
    final data = existing.data();
    final document = documentNumber?.trim().isNotEmpty == true
        ? documentNumber!.trim()
        : (data?['document']?.toString().trim().isNotEmpty == true
            ? data!['document'].toString().trim()
            : data?['documentNumber']?.toString().trim());
    final existingRoles = _rolesFromProfile(data);
    final roles = {
      ...existingRoles,
      if (existingRoles.isEmpty) 'jugador',
    };
    await ref.set({
      'uid': user.uid,
      'email': user.email?.trim().toLowerCase(),
      'displayName': name?.isNotEmpty == true ? name : (data?['displayName'] ?? data?['nombre'] ?? user.displayName ?? ''),
      'roles': roles.toList(),
      'correo': FieldValue.delete(),
      'nombre': FieldValue.delete(),
      'telefono': FieldValue.delete(),
      'nivel': FieldValue.delete(),
      'rol': FieldValue.delete(),
      if (data?['displayName'] != null) 'displayName': data!['displayName'],
      if (document != null && document.isNotEmpty) 'document': document,
      if (document != null && document.isNotEmpty) 'documentNumber': document,
      if (data?['document'] != null) 'document': data!['document'],
      if (data?['accreditation'] != null) 'accreditation': data!['accreditation'],
      if (data?['category'] != null) 'category': data!['category'],
      if (data?['phone'] != null) 'phone': data!['phone'],
      if (data?['documentNumber'] != null) 'documentNumber': data!['documentNumber'],
      if (data?['shirtNumber'] != null) 'shirtNumber': data!['shirtNumber'],
      if (data?['position'] != null) 'position': data!['position'],
      if (data?['teamName'] != null) 'teamName': data!['teamName'],
      if (data?['nivel'] != null) 'nivel': data!['nivel'],
      'updatedAt': FieldValue.serverTimestamp(),
      if (!existing.exists) 'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await FirebaseFirestore.instance.collection('profile_directory').doc(user.uid).set({
      'uid': user.uid,
      'name': name?.isNotEmpty == true ? name : (data?['displayName'] ?? data?['nombre'] ?? user.displayName ?? ''),
      'document': data?['document'] ?? data?['documentNumber'] ?? '',
      'email': user.email?.trim().toLowerCase() ?? '',
      'phone': data?['phone'] ?? '',
      'roles': roles.toList(),
      'shirtNumber': data?['shirtNumber'] ?? '',
      'position': data?['position'] ?? '',
      'teamName': data?['teamName'] ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// ES: Combina la lista de roles actual con el campo de rol heredado.
  /// EN: Collects modern role arrays and legacy single-role profile fields.
  Set<String> _rolesFromProfile(Map<String, dynamic>? profile) {
    if (profile == null) return <String>{};
    final roles = (profile['roles'] as List?)
            ?.map((value) => value.toString().trim().toLowerCase())
            .where((value) => value.isNotEmpty)
            .toSet() ??
        <String>{};
    final primaryRole = profile['rol']?.toString().trim().toLowerCase();
    if (primaryRole != null && primaryRole.isNotEmpty) roles.add(primaryRole);
    return roles;
  }

  /// ES: Envía el correo de recuperación y traduce errores de Firebase Auth.
  /// EN: Sends a password-reset email and translates Firebase Auth errors.
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email.trim());
    } on fb.FirebaseAuthException catch (e) {
      throw ServerException(mapFirebaseAuthError(e.code));
    }
  }

  /// ES: Cierra Firebase y limpia cualquier sesión de Google Sign-In.
  /// EN: Signs out of Firebase and clears any Google Sign-In session.
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
