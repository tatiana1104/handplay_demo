import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../shared/widgets/app_bottom_navigation_bar.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthFailure) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(state.message)));
        }
        // No navegamos manualmente a RouteNames.home en AuthAuthenticated:
        // el `redirect` de GoRouter en main.dart ya se encarga de eso en
        // cuanto el AuthBloc emite ese estado.
      },
      child: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          final loading = state is AuthLoading;
          return Scaffold(
            backgroundColor: colors.surface,
            body: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Center(child: Container(width: 82, height: 82, decoration: BoxDecoration(color: colors.primary, borderRadius: BorderRadius.circular(20)), child: Icon(AppConstants.appLogoIcon, size: 44, color: colors.onPrimary))),
                      const SizedBox(height: 20),
                      Text('Bienvenido a ${AppConstants.appName}', textAlign: TextAlign.center, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: colors.onSurface)),
                      const SizedBox(height: 6),
                      Text(AppConstants.ligaNombre, textAlign: TextAlign.center, style: TextStyle(color: colors.onSurfaceVariant)),
                      const SizedBox(height: 28),
                      TextField(controller: _email, enabled: !loading, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Correo electrónico')),
                      const SizedBox(height: 18),
                      TextField(controller: _password, enabled: !loading, obscureText: true, decoration: const InputDecoration(labelText: 'Contraseña')),
                      Align(alignment: Alignment.centerRight, child: TextButton(onPressed: loading ? null : () => context.go(RouteNames.recoverPassword), child: const Text('¿Olvidaste tu contraseña?'))),
                      const SizedBox(height: 10),
                      FilledButton(
                        onPressed: loading
                            ? null
                            : () => context.read<AuthBloc>().add(
                                  AuthLoginRequested(email: _email.text, password: _password.text),
                                ),
                        child: loading
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Iniciar sesión'),
                      ),
                      const SizedBox(height: 18),
                      OutlinedButton.icon(
                        onPressed: loading
                            ? null
                            : () => context.read<AuthBloc>().add(const AuthGoogleSignInRequested()),
                        icon: const Text('G', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        label: Text(AppConstants.googleButton),
                      ),
                      const SizedBox(height: 18),
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text('¿No tienes cuenta?', style: TextStyle(color: colors.onSurfaceVariant)), TextButton(onPressed: loading ? null : () => context.go(RouteNames.register), child: const Text('Regístrate'))]),
                    ]),
                  ),
                ),
              ),
            ),
            // Login sigue siendo una vista pública: muestra Home e Iniciar sesión,
            // no las opciones de usuario autenticado.
            bottomNavigationBar: const AppBottomNavigationBar(
              selectedIndex: 1,
              isAuthenticated: false,
            ),
          );
        },
      ),
    );
  }
}
