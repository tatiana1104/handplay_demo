import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'core/constants/app_constants.dart';
import 'core/routing/route_names.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/auth/presentation/screens/recover_password_screen.dart';
import 'features/auth/presentation/screens/register_screen.dart';
import 'features/auth/presentation/screens/splash_screen.dart';
import 'features/tournaments/presentation/screens/torneos_screen.dart';
import 'features/tournaments/data/tournament_repository.dart';
import 'features/tournaments/presentation/screens/tournament_detail_screen.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const HandPlayApp());
}

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<Object?> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<Object?> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
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
    _authBloc = AuthBloc();
    _router = GoRouter(
      initialLocation: RouteNames.splash,
      refreshListenable: GoRouterRefreshStream(_authBloc.stream),
      redirect: (context, state) {
        final authState = _authBloc.state;
        final isPublicRoute = <String>{
          RouteNames.splash,
          RouteNames.login,
          RouteNames.register,
          RouteNames.recoverPassword,
        }.contains(state.matchedLocation);

        if (authState.status == AuthStatus.unknown) {
          return state.matchedLocation == RouteNames.splash
              ? null
              : RouteNames.splash;
        }

        if (!authState.isAuthenticated && !isPublicRoute) {
          return RouteNames.login;
        }

        if (authState.isAuthenticated &&
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
          path: '${RouteNames.tournament}/:tournamentId',
          builder: (context, state) => TournamentDetailScreen(
            tournament: state.extra! as Tournament,
          ),
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
    _authBloc.close();
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
