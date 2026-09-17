/// Traduce los códigos de error de `FirebaseAuthException` a mensajes
/// en español, entendibles para entrenadores/árbitros/administradores
/// sin conocimiento técnico (ver RNF-04, usabilidad).
///
/// Referencia de códigos:
/// https://firebase.google.com/docs/reference/js/auth#autherrorcodes
String mapFirebaseAuthError(String code) {
  switch (code) {
    case 'invalid-email':
      return 'El correo electrónico no es válido.';
    case 'user-disabled':
      return 'Esta cuenta fue deshabilitada. Contacta al administrador de la Liga.';
    case 'user-not-found':
      return 'No existe una cuenta con ese correo.';
    case 'wrong-password':
    case 'invalid-credential':
      return 'Correo o contraseña incorrectos.';
    case 'email-already-in-use':
      return 'Ya existe una cuenta con ese correo.';
    case 'weak-password':
      return 'La contraseña es muy débil. Usa al menos 6 caracteres.';
    case 'operation-not-allowed':
      return 'Este método de inicio de sesión no está habilitado. Contacta al administrador.';
    case 'too-many-requests':
      return 'Demasiados intentos. Espera un momento antes de volver a intentar.';
    case 'network-request-failed':
      return 'No hay conexión a internet. Verifica tu red e intenta de nuevo.';
    case 'account-exists-with-different-credential':
      return 'Ya existe una cuenta con ese correo usando otro método de inicio de sesión.';
    case 'requires-recent-login':
      return 'Esta acción requiere que vuelvas a iniciar sesión.';
    default:
      return 'Ocurrió un error inesperado ($code). Intenta de nuevo.';
  }
}
