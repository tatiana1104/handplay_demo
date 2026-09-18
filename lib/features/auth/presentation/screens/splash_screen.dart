import 'package:flutter/material.dart'; 
import '../../../../core/constants/app_constants.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {

    });
  }

  @override
  void dispose() {
    _redirectTimer?.cancel(); // Cancelamos el `Timer` si todavía está activo cuando el widget se desmonta para evitar que intente navegar a la pantalla de inicio después de que el widget ya no esté en el árbol de widgets
    super.dispose(); // Llamamos a `super.dispose()` para asegurarnos de que cualquier limpieza adicional del estado del widget se realice correctamente cuando el widget se desmonta
  }

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
            CircularProgressIndicator(
              color: Theme.of(context).colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }
}
