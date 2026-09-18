import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
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
import 'features/matches/presentation/screens/calendar_screen.dart';
import 'features/matches/presentation/screens/live_match_screen.dart';
import 'features/referees/presentation/screens/referees_screen.dart';
import 'features/tournaments/presentation/screens/create_tournament_screen.dart';
import 'features/tournaments/presentation/screens/torneos_screen.dart';
import 'features/tournaments/presentation/screens/tournament_detail_screen.dart';
import 'features/tournaments/domain/models/tournament_models.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
    provisional: false,
  ).catchError((error) {
    debugPrint('[v0] No se pudo solicitar permiso de notificaciones: $error');
  });
  FirebaseMessaging.onMessage.listen((message) {
    debugPrint('[v0] Notificación recibida: ${message.notification?.title}');
  });
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
        final normalizedRoles = authState is AuthAuthenticated
            ? authState.user.roles.map((role) => role.trim().toLowerCase()).toSet()
            : const <String>{};
        final isPublicRole = normalizedRoles.contains('publico') ||
            normalizedRoles.contains('public') ||
            normalizedRoles.contains('público');
        final isInitial = authState is AuthInitial || authState is AuthLoading;
        // Home es una vista pública: permite conocer la app sin iniciar sesión.
        final isPublicRoute = <String>{
          RouteNames.splash,
          RouteNames.home,
          RouteNames.tournamentDetail,
          RouteNames.calendar,
          RouteNames.liveMatch,
          RouteNames.login,
          RouteNames.register,
          RouteNames.recoverPassword,
        }.contains(state.matchedLocation);

        if (isInitial) {
          return state.matchedLocation == RouteNames.splash
              ? null
              : RouteNames.splash;
        }

        // Visitantes y cuentas con rol público solo pueden navegar por las
        // pantallas informativas; nunca deben ser enviados a Perfil o Login.
        if ((!isAuthenticated || isPublicRole) && !isPublicRoute) {
          return RouteNames.home;
        }

        // El detalle del torneo es de solo lectura y puede ser consultado por
        // visitantes, cuentas públicas, administradores y usuarios autenticados.
        if (isPublicRoute) {
          return null;
        }

        if (state.matchedLocation == RouteNames.splash) {
          return isAuthenticated && !isPublicRole ? RouteNames.profile : RouteNames.home;
        }

        if (isAuthenticated &&
            (state.matchedLocation == RouteNames.login ||
                state.matchedLocation == RouteNames.register ||
                state.matchedLocation == RouteNames.recoverPassword ||
                state.matchedLocation == RouteNames.splash)) {
          return RouteNames.profile;
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
          path: RouteNames.tournamentDetail,
          builder: (context, state) {
            final tournament = state.extra;
            return tournament is Tournament ? TournamentDetailScreen(tournament: tournament) : const TorneosScreen();
          },
        ),
        GoRoute(
          path: RouteNames.profile,
          builder: (context, state) => const ProfileScreen(),
        ),
        GoRoute(
          path: RouteNames.calendar,
          builder: (context, state) => const CalendarScreen(),
        ),
        GoRoute(
          path: RouteNames.referees,
          builder: (context, state) => const RefereesScreen(),
        ),
        GoRoute(
          path: RouteNames.internal,
          builder: (context, state) => state.extra is Widget ? state.extra as Widget : const TorneosScreen(),
        ),
        GoRoute(
          path: RouteNames.liveMatch,
          builder: (context, state) {
            final data = state.extra is Map ? Map<String, dynamic>.from(state.extra as Map) : <String, dynamic>{};
            return LiveMatchScreen(matchId: data['id']?.toString() ?? '', match: data);
          },
        ),
        GoRoute(
          path: RouteNames.createTournament,
          builder: (context, state) {
            final extraAdminId = state.extra;
            final adminId = extraAdminId is String && extraAdminId.isNotEmpty
                ? extraAdminId
                : FirebaseAuth.instance.currentUser?.uid;

            if (adminId == null || adminId.isEmpty) {
              return const TorneosScreen();
            }

            return CreateTournamentScreen(adminId: adminId);
          },
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
