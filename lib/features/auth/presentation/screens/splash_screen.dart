import 'package:flutter/material.dart'; 
import '../../../../core/constants/app_constants.dart';

/// Pantalla inicial que muestra la marca mientras se prepara la navegación.
/// ES: Pantalla inicial que muestra la marca mientras se prepara la navegación.
/// EN: Initial screen that shows the brand while navigation is prepared.
class SplashScreen extends StatefulWidget {
  /// Crea la pantalla de inicio.
  /// ES: Crea la pantalla de inicio.
  /// EN: Creates the startup screen.
  const SplashScreen({super.key});

  /// Crea el estado usado para construir la interfaz del splash.
  @override
  /// ES: Crea el estado que construye la interfaz del splash.
  /// EN: Creates the state that builds the splash interface.
  State<SplashScreen> createState() => _SplashScreenState();
}

/// Estado de la pantalla splash; no necesita datos mutables propios.
/// ES: Estado del splash, sin datos mutables propios.
/// EN: Splash state; it has no mutable data of its own.
class _SplashScreenState extends State<SplashScreen> {
  /// Muestra el logo, el nombre de la app y el indicador de carga.
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      // Usa la superficie de la paleta desde el primer frame de Flutter,
      // evitando que el splash aparezca con un blanco distinto al resto.
      backgroundColor: colors.surface,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ES: Identidad visual de la aplicación.
            // EN: Application branding.
            Icon(
              AppConstants.appLogoIcon,
              size: 72,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              AppConstants.appName,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            // ES: Indica que la app sigue resolviendo su estado inicial.
            // EN: Indicates that the app is resolving its initial state.
            CircularProgressIndicator(
              color: Theme.of(context).colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }
}
