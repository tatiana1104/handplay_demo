import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../shared/widgets/app_bottom_navigation_bar.dart';
import '../../data/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _auth = AuthService();
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await action();
      if (mounted) context.go(RouteNames.home);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(authErrorMessage(error))));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
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
                TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Correo electrónico')),
                const SizedBox(height: 18),
                TextField(controller: _password, obscureText: true, decoration: const InputDecoration(labelText: 'Contraseña')),
                Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => context.go(RouteNames.recoverPassword), child: const Text('¿Olvidaste tu contraseña?'))),
                const SizedBox(height: 10),
                FilledButton(onPressed: _loading ? null : () => _run(() async => _auth.signIn(email: _email.text, password: _password.text)), child: _loading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Iniciar sesión')),
                const SizedBox(height: 18),
                OutlinedButton.icon(onPressed: _loading ? null : () => _run(() async => _auth.signInWithGoogle()), icon: const Text('G', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), label: Text(AppConstants.googleButton)),
                const SizedBox(height: 18),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text('¿No tienes cuenta?', style: TextStyle(color: colors.onSurfaceVariant)), TextButton(onPressed: () => context.go(RouteNames.register), child: const Text('Regístrate'))]),
              ]),
            ),
          ),
        ),
      ),
      bottomNavigationBar: const AppBottomNavigationBar(selectedIndex: 2),
    );
  }
}
