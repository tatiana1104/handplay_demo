import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'core/constants/app_constants.dart';
import 'core/di/injection_container.dart';
import 'core/routing/go_router_refresh_stream.dart';
import 'core/routing/route_names.dart'; // Importamos los nombres de ruta para poder usarlos en el router
import 'core/theme/app_theme.dart'; // Importamos el tema de la app para poder usarlo en MaterialApp.router
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/bloc/auth_state.dart';
import 'features/auth/presentation/screens/login_screen.dart'; // Importamos la pantalla de login para poder usarla en el router
import 'features/auth/presentation/screens/recover_password_screen.dart'; // Importamos la pantalla de recuperación de contraseña para poder usarla en el router
import 'features/auth/presentation/screens/register_screen.dart'; // Importamos la pantalla de registro para poder usarla en el router
import 'features/auth/presentation/screens/splash_screen.dart'; // Importamos la pantalla de splash para poder usarla en el router
import 'features/tournaments/presentation/screens/torneos_screen.dart'; // Importamos la pantalla de torneos para poder usarla en el router
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Debe llamarse una sola vez, antes de cualquier
  // `GoogleSignIn.instance.authenticate()` (ver AuthRemoteDataSource).
  // `serverClientId` es necesario en Android para que el idToken que
  // devuelve Google tenga la audiencia correcta y Firebase lo acepte.
  await GoogleSignIn.instance.initialize(
    serverClientId: AppConstants.googleServerClientId,
  );

  // Service locator: registra AuthRemoteDataSource, AuthRepository, los
  // casos de uso y el AuthBloc (ver core/di/injection_container.dart).
  await initDependencies();

  // El AuthBloc vive durante toda la app (singleton en get_it): escucha
  // authStateChanges de Firebase y por eso también decide, junto con el
  // router, quién puede ver qué pantalla.
  final authBloc = sl<AuthBloc>();

  runApp(HandPlayApp(authBloc: authBloc));
}

class HandPlayApp extends StatelessWidget {
  final AuthBloc authBloc;

  const HandPlayApp({super.key, required this.authBloc});

  @override
  Widget build(BuildContext context) {
    final router = GoRouter(
      initialLocation: RouteNames.splash, // Definimos la ruta inicial de la app como la pantalla de splash
      // Cada vez que el AuthBloc emite un nuevo estado, esto le avisa a
      // GoRouter que vuelva a evaluar `redirect` de abajo — así un login
      // exitoso, por ejemplo, saca solo al usuario del login sin que la
      // pantalla tenga que hacer context.go() a mano.
      refreshListenable: GoRouterRefreshStream(authBloc.stream),
      redirect: (context, state) {
        final authState = authBloc.state;
        final knowsAuthStatus =
            authState is AuthAuthenticated || authState is AuthUnauthenticated;
        final isLoggedIn = authState is AuthAuthenticated;

        const authScreens = {
          RouteNames.login,
          RouteNames.register,
          RouteNames.recoverPassword,
        };
        final goingToAuthScreen = authScreens.contains(state.matchedLocation);
        final goingToSplash = state.matchedLocation == RouteNames.splash;

        if (!knowsAuthStatus) {
          // Firebase todavía no resolvió si hay una sesión activa
          // (arranque en frío). No redirigimos todavía: la splash se
          // encarga de esperar antes de navegar.
          return null;
        }

        if (!isLoggedIn && !goingToAuthScreen) {
          // Nadie sin sesión puede ver torneos, calendario, etc.
          return RouteNames.login;
        }

        if (isLoggedIn && (goingToAuthScreen || goingToSplash)) {
          // Alguien ya logueado no debería ver login/registro/splash otra vez.
          return RouteNames.home;
        }

        return null;
      },
      routes: [
        GoRoute(
          path: RouteNames.splash, // Definimos la ruta de la pantalla de splash
          builder: (context, state) => const SplashScreen(), // Construimos la pantalla de splash cuando se navega a esta ruta
        ),
        GoRoute(
          path: RouteNames.home,
          builder: (context, state) => const TorneosScreen(), // Construimos la pantalla de torneos cuando se navega a esta ruta
        ),
        GoRoute(
          path: RouteNames.login,
          builder: (context, state) => const LoginScreen(), // Construimos la pantalla de login cuando se navega a esta ruta
        ),
        GoRoute(
          path: RouteNames.register,
          builder: (context, state) => const RegisterScreen(), // Construimos la pantalla de registro cuando se navega a esta ruta
        ),
        GoRoute(
          path: RouteNames.recoverPassword,
          builder: (context, state) => const RecoverPasswordScreen(), // Construimos la pantalla de recuperación cuando se navega a esta ruta
        ),
      ],
    );

    return BlocProvider.value(
      value: authBloc,
      child: MaterialApp.router(
        title: AppConstants.appName, // Definimos el título de la app que se muestra en la barra de tareas y en el switcher de apps
        theme: AppTheme.light, // Definimos el tema claro de la app que se aplica cuando el sistema está en modo claro
        darkTheme: AppTheme.dark, // Definimos el tema oscuro de la app que se aplica cuando el sistema está en modo oscuro
        themeMode: ThemeMode.system, // Definimos que el tema de la app se adapte al modo del sistema operativo (claro/oscuro)
        routerConfig: router, // Configuramos el router de la app con las rutas definidas arriba
        debugShowCheckedModeBanner: false, // Ocultamos el banner de debug que aparece en la esquina superior derecha cuando la app está en modo debug
      ),
    );
  }
}
