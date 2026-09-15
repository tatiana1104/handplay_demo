import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/constants/app_constants.dart';
import 'firebase_options.dart';
import 'core/routing/route_names.dart'; // Importamos los nombres de ruta para poder usarlos en el router
import 'core/theme/app_theme.dart'; // Importamos el tema de la app para poder usarlo en MaterialApp.router
import 'features/auth/presentation/screens/login_screen.dart'; // Importamos la pantalla de login para poder usarla en el router
import 'features/auth/presentation/screens/recover_password_screen.dart'; // Importamos la pantalla de recuperación de contraseña para poder usarla en el router
import 'features/auth/presentation/screens/register_screen.dart'; // Importamos la pantalla de registro para poder usarla en el router
import 'features/auth/presentation/screens/splash_screen.dart'; // Importamos la pantalla de splash para poder usarla en el router
import 'features/tournaments/presentation/screens/torneos_screen.dart'; // Importamos la pantalla de torneos para poder usarla en el router

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const HandPlayApp());
}

class HandPlayApp extends StatelessWidget {
  const HandPlayApp({super.key});

  @override
  Widget build(BuildContext context) {
    final router = GoRouter(
      initialLocation: RouteNames.splash, // Definimos la ruta inicial de la app como la pantalla de splash
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

    return MaterialApp.router(
      title: AppConstants.appName, // Definimos el título de la app que se muestra en la barra de tareas y en el switcher de apps
      theme: AppTheme.light, // Definimos el tema claro de la app que se aplica cuando el sistema está en modo claro
      darkTheme: AppTheme.dark, // Definimos el tema oscuro de la app que se aplica cuando el sistema está en modo oscuro
      themeMode: ThemeMode.system, // Definimos que el tema de la app se adapte al modo del sistema operativo (claro/oscuro)
      routerConfig: router, // Configuramos el router de la app con las rutas definidas arriba
      debugShowCheckedModeBanner: false, // Ocultamos el banner de debug que aparece en la esquina superior derecha cuando la app está en modo debug
    );
  }
}
