import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/routing/route_names.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _showPassword = false;
  bool _showConfirmation = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  void _register(BuildContext context) {
    if (_password.text != _confirmation.text) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Las contraseñas no coinciden.')));
      return;
    }
    context.read<AuthBloc>().add(
          AuthRegisterRequested(
            name: _name.text,
            email: _email.text,
            password: _password.text,
          ),
        );
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
        // AuthAuthenticated tras registrarse: el `redirect` de
        // GoRouter en main.dart saca de esta pantalla automáticamente.
      },
      child: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          final loading = state is AuthLoading;
          return Scaffold(
            backgroundColor: colors.surface,
            body: SafeArea(child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: loading ? null : () => context.go(RouteNames.login), icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18), label: const Text('Volver'))),
              const SizedBox(height: 8),
              Center(child: Container(width: 82, height: 82, decoration: BoxDecoration(color: colors.primary, borderRadius: BorderRadius.circular(20)), child: Icon(AppConstants.appLogoIcon, size: 44, color: colors.onPrimary))),
              const SizedBox(height: 20),
              Text('Crear cuenta', textAlign: TextAlign.center, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: colors.onSurface)),
              const SizedBox(height: 6),
              Text('Crea tu cuenta para acceder a torneos y estadísticas. Usa el mismo correo que registrarás como entrenador para vincular tu equipo.', textAlign: TextAlign.center, style: TextStyle(color: colors.onSurfaceVariant)),
              const SizedBox(height: 28),
              TextField(controller: _name, enabled: !loading, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Nombre completo')),
              const SizedBox(height: 18),
              TextField(controller: _email, enabled: !loading, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Correo electrónico')),
              const SizedBox(height: 18),
              TextField(controller: _password, enabled: !loading, obscureText: !_showPassword, decoration: InputDecoration(labelText: 'Contraseña', suffixIcon: IconButton(tooltip: _showPassword ? 'Ocultar contraseña' : 'Mostrar contraseña', onPressed: () => setState(() => _showPassword = !_showPassword), icon: Icon(_showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined)))),
              const SizedBox(height: 18),
              TextField(controller: _confirmation, enabled: !loading, obscureText: !_showConfirmation, decoration: InputDecoration(labelText: 'Confirmar contraseña', suffixIcon: IconButton(tooltip: _showConfirmation ? 'Ocultar contraseña' : 'Mostrar contraseña', onPressed: () => setState(() => _showConfirmation = !_showConfirmation), icon: Icon(_showConfirmation ? Icons.visibility_off_outlined : Icons.visibility_outlined)))),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: loading ? null : () => _register(context),
                child: loading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Crear cuenta'),
              ),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: loading ? null : () => context.read<AuthBloc>().add(const AuthGoogleSignInRequested()),
                icon: const Text('G', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                label: Text(AppConstants.googleButton),
              ),
              const SizedBox(height: 24),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text('¿Ya tienes una cuenta?', style: TextStyle(color: colors.onSurfaceVariant)), TextButton(onPressed: loading ? null : () => context.go(RouteNames.login), child: const Text('Inicia sesión'))]),
            ]))))),
          );
        },
      ),
    );
  }
}
