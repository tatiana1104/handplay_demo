import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:get_it/get_it.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../features/auth/data/datasources/auth_remote_datasource.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/usecases/register_with_email_password.dart';
import '../../features/auth/domain/usecases/send_password_reset_email.dart';
import '../../features/auth/domain/usecases/sign_in_with_email_password.dart';
import '../../features/auth/domain/usecases/sign_in_with_google.dart';
import '../../features/auth/domain/usecases/sign_out.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';

/// Service locator de la app (patrón `get_it`). `initDependencies()`
/// se llama una sola vez, en `main()`, antes de `runApp`.
///
/// Por ahora solo registra el feature de auth; cada nuevo feature
/// (torneos, equipos, partidos...) agrega su propia función
/// `_initXxxDependencies()` y la llama desde acá, siguiendo el mismo
/// patrón, en vez de mezclar todo en una sola función gigante.
final GetIt sl = GetIt.instance;

Future<void> initDependencies() async {
  _initAuthDependencies();
}

void _initAuthDependencies() {
  // --- SDKs externos ---
  sl.registerLazySingleton<fb.FirebaseAuth>(() => fb.FirebaseAuth.instance);
  sl.registerLazySingleton<GoogleSignIn>(() => GoogleSignIn.instance);

  // --- Data layer ---
  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSource(firebaseAuth: sl(), googleSignIn: sl()),
  );

  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(sl()),
  );

  // --- Domain layer (casos de uso) ---
  sl.registerLazySingleton(() => SignInWithEmailPassword(sl()));
  sl.registerLazySingleton(() => RegisterWithEmailPassword(sl()));
  sl.registerLazySingleton(() => SignInWithGoogle(sl()));
  sl.registerLazySingleton(() => SendPasswordResetEmail(sl()));
  sl.registerLazySingleton(() => SignOut(sl()));

  // --- Presentation layer ---
  // Singleton (no factory): el bloc mantiene abierta la suscripción al
  // stream de `authStateChanges` durante toda la vida de la app.
  sl.registerLazySingleton(
    () => AuthBloc(
      signIn: sl(),
      register: sl(),
      signInWithGoogle: sl(),
      sendPasswordResetEmail: sl(),
      signOut: sl(),
      authRepository: sl(),
    ),
  );
}
