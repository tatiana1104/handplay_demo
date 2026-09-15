import 'dart:async'; // Importamos la librería `dart:async` para poder usar `Timer` en la pantalla de splash

import 'package:flutter/material.dart'; 
import 'package:go_router/go_router.dart'; // Importamos la librería `go_router` para poder navegar entre pantallas usando rutas definidas en `RouteNames`

import '../../../../core/constants/app_constants.dart'; // Importamos las constantes de la app, como el nombre de la app, para poder usarlas en la pantalla de splash
import '../../../../core/routing/route_names.dart'; // Importamos los nombres de ruta de la app, como `RouteNames.home`, para poder navegar a la pantalla de inicio desde la pantalla de splash

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _redirectTimer; // Declaramos un `Timer` que se usará para redirigir a la pantalla de inicio después de un tiempo determinado (1.5 segundos) desde la pantalla de splash

  @override
  void initState() {
    super.initState(); // Inicializamos el estado del widget y configuramos el `Timer` para redirigir a la pantalla de inicio después de 1.5 segundos
    _redirectTimer = Timer(const Duration(milliseconds: 1500), () { // Configuramos un `Timer` que se ejecutará después de 1.5 segundos (1500 milisegundos) desde que se muestra la pantalla de splash
      if (mounted) { // Verificamos que el widget todavía esté montado en el árbol de widgets antes de navegar a la pantalla de inicio para evitar errores si el widget se ha desmontado
        context.go(RouteNames.home); // Usamos `context.go` de `go_router` para navegar a la pantalla de inicio (`RouteNames.home`) después de que el `Timer` se dispare
      }
    });
  }

  @override
  void dispose() {
    _redirectTimer?.cancel(); // Cancelamos el `Timer` si todavía está activo cuando el widget se desmonta para evitar que intente navegar a la pantalla de inicio después de que el widget ya no esté en el árbol de widgets
    super.dispose(); // Llamamos a `super.dispose()` para asegurarnos de que cualquier limpieza adicional del estado del widget se realice correctamente cuando el widget se desmonta
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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