import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/routing/route_names.dart';
import '../../data/auth_service.dart';

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
  final _auth = AuthService();
  bool _loading = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (_password.text != _confirmation.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Las contraseñas no coinciden.')));
      return;
    }
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await _auth.register(email: _email.text, password: _password.text, displayName: _name.text);
      if (mounted) context.go(RouteNames.home);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(authErrorMessage(error))));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _google() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await _auth.signInWithGoogle();
      if (mounted) context.go(RouteNames.home);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(authErrorMessage(error))));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: () => context.go(RouteNames.login), icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18), label: const Text('Volver'))),
        const SizedBox(height: 8),
        Center(child: Container(width: 82, height: 82, decoration: BoxDecoration(color: colors.primary, borderRadius: BorderRadius.circular(20)), child: Icon(AppConstants.appLogoIcon, size: 44, color: colors.onPrimary))),
        const SizedBox(height: 20),
        Text('Crear cuenta', textAlign: TextAlign.center, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: colors.onSurface)),
        const SizedBox(height: 6),
        Text('Crea tu cuenta para acceder a torneos y estadísticas.', textAlign: TextAlign.center, style: TextStyle(color: colors.onSurfaceVariant)),
        const SizedBox(height: 28),
        TextField(controller: _name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Nombre completo')),
        const SizedBox(height: 18),
        TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Correo electrónico')),
        const SizedBox(height: 18),
        TextField(controller: _password, obscureText: true, decoration: const InputDecoration(labelText: 'Contraseña')),
        const SizedBox(height: 18),
        TextField(controller: _confirmation, obscureText: true, decoration: const InputDecoration(labelText: 'Confirmar contraseña')),
        const SizedBox(height: 24),
        FilledButton(onPressed: _loading ? null : _register, child: _loading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Crear cuenta')),
        const SizedBox(height: 18),
        OutlinedButton.icon(onPressed: _loading ? null : _google, icon: const Text('G', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), label: Text(AppConstants.googleButton)),
        const SizedBox(height: 24),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text('¿Ya tienes una cuenta?', style: TextStyle(color: colors.onSurfaceVariant)), TextButton(onPressed: () => context.go(RouteNames.login), child: const Text('Inicia sesión'))]),
      ]))))),
    );
  }
}
