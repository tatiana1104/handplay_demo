import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// ES: Encapsula las operaciones de Firebase Auth y Google Sign-In.
/// EN: Wraps Firebase Authentication and Google Sign-In operations.
class AuthService {
  /// ES: Crea el servicio con el cliente Firebase Auth recibido o predeterminado.
  /// EN: Creates the service with a supplied or default Firebase Auth client.
  AuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  bool _googleInitialized = false;

  /// ES: Inicia sesión con correo electrónico y contraseña.
  /// EN: Signs in an existing account using email and password.
  Future<UserCredential> signIn({required String email, required String password}) {
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// ES: Crea una cuenta por correo y establece su nombre visible.
  /// EN: Creates an email account and sets its display name.
  Future<UserCredential> register({required String email, required String password, required String displayName}) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await credential.user?.updateDisplayName(displayName.trim());
    return credential;
  }

  /// ES: Inicializa Google Sign-In una vez y autentica con Firebase.
  /// EN: Initializes Google Sign-In once and authenticates with Firebase.
  Future<UserCredential> signInWithGoogle() async {
    if (!_googleInitialized) {
      await _googleSignIn.initialize();
      _googleInitialized = true;
    }
    final account = await _googleSignIn.authenticate();
    final authentication = account.authentication;
    final credential = GoogleAuthProvider.credential(idToken: authentication.idToken);
    return _auth.signInWithCredential(credential);
  }

  /// ES: Solicita a Firebase el correo de restablecimiento de contraseña.
  /// EN: Sends Firebase's password-reset email.
  Future<void> sendPasswordResetEmail(String email) {
    return _auth.sendPasswordResetEmail(email: email.trim());
  }
}

/// ES: Convierte excepciones de autenticación en mensajes para la interfaz.
/// EN: Converts authentication exceptions into user-facing messages.
String authErrorMessage(Object error) {
  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'El correo o la contraseña no son correctos.';
      case 'email-already-in-use':
        return 'Ya existe una cuenta con este correo.';
      case 'weak-password':
        return 'La contraseña debe tener al menos 6 caracteres.';
      case 'invalid-email':
        return 'Introduce un correo electrónico válido.';
      case 'network-request-failed':
        return 'No hay conexión. Comprueba tu conexión a internet.';
      case 'popup-closed-by-user':
        return 'Se canceló el inicio de sesión con Google.';
      default:
        return error.message ?? 'No se pudo completar la operación.';
    }
  }
  return 'No se pudo completar la operación. Inténtalo de nuevo.';
}
