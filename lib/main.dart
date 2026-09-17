import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'core/constants/app_constants.dart';
import 'core/di/injection_container.dart';
import 'core/routing/go_router_refresh_stream.dart';
import 'core/routing/route_names.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/bloc/auth_state.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/auth/presentation/screens/profile_screen.dart';
import 'features/auth/presentation/screens/recover_password_screen.dart';
import 'features/auth/presentation/screens/register_screen.dart';
import 'features/auth/presentation/screens/splash_screen.dart';
import 'features/tournaments/presentation/screens/torneos_screen.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await initDependencies();
  runApp(const HandPlayApp());
}

class HandPlayApp extends StatefulWidget {
  const HandPlayApp({super.key});

  @override
  State<HandPlayApp> createState() => _HandPlayAppState();
}

class _HandPlayAppState extends State<HandPlayApp> {
  late final AuthBloc _authBloc;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _authBloc = sl<AuthBloc>();
    _router = GoRouter(
      initialLocation: RouteNames.splash,
      refreshListenable: GoRouterRefreshStream(_authBloc.stream),
      redirect: (context, state) {
        final authState = _authBloc.state;
        final isAuthenticated = authState is AuthAuthenticated;
        final isInitial = authState is AuthInitial || authState is AuthLoading;
        // Home es una vista pública: permite conocer la app sin iniciar sesión.
        final isPublicRoute = <String>{
          RouteNames.splash,
          RouteNames.home,
          RouteNames.login,
          RouteNames.register,
          RouteNames.recoverPassword,
        }.contains(state.matchedLocation);

        if (isInitial) {
          return state.matchedLocation == RouteNames.splash
              ? null
              : RouteNames.splash;
        }

        if (!isAuthenticated && !isPublicRoute) {
          return RouteNames.login;
        }

        if (isAuthenticated &&
            (state.matchedLocation == RouteNames.login ||
                state.matchedLocation == RouteNames.register ||
                state.matchedLocation == RouteNames.recoverPassword ||
                state.matchedLocation == RouteNames.splash)) {
          return RouteNames.home;
        }

        return null;
      },
      routes: [
        GoRoute(
          path: RouteNames.splash,
          builder: (context, state) => const SplashScreen(),
        ),
        GoRoute(
          path: RouteNames.home,
          builder: (context, state) => const TorneosScreen(),
        ),
        GoRoute(
          path: RouteNames.profile,
          builder: (context, state) => const ProfileScreen(),
        ),
        GoRoute(
          path: RouteNames.login,
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: RouteNames.register,
          builder: (context, state) => const RegisterScreen(),
        ),
        GoRoute(
          path: RouteNames.recoverPassword,
          builder: (context, state) => const RecoverPasswordScreen(),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _authBloc,
      child: MaterialApp.router(
        title: AppConstants.appName,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.system,
        routerConfig: _router,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
