import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/bloc/auth_state.dart';

import '../../core/routing/route_names.dart'; // Importamos los nombres de ruta de la app, como `RouteNames.home`, para poder navegar a la pantalla de inicio desde la barra de navegación inferior

class AppBottomNavigationBar extends StatelessWidget {
  final int selectedIndex; // Índice del elemento seleccionado en la barra de navegación inferior (0 = Home, 1 = Calendario, 2 = Perfil)
  final bool isAuthenticated; // Cambia las acciones disponibles para visitantes.
  final bool isAdmin;
  final ValueChanged<int>? onTap; // Callback que se ejecuta cuando se toca un elemento de la barra de navegación inferior. Si es nulo, se usa la navegación por defecto a las rutas definidas en `RouteNames`.

  /// Constructor de la barra de navegación inferior, con parámetros opcionales `selectedIndex` y `onTap`.
  const AppBottomNavigationBar({
    super.key, 
    this.selectedIndex = 0, // Índice del elemento seleccionado en la barra de navegación inferior (0 = Home, 1 = Calendario, 2 = Perfil)
    this.isAuthenticated = true,
    this.isAdmin = false,
    this.onTap, // Callback que se ejecuta cuando se toca un elemento de la barra de navegación inferior. Si es nulo, se usa la navegación por defecto a las rutas definidas en `RouteNames`.
  });

  int _safeSelectedIndex(int index, bool authenticated, bool admin) {
    final itemCount = authenticated ? (admin ? 4 : 3) : 3;
    return index >= 0 && index < itemCount ? index : 0;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final authState = context.watch<AuthBloc>().state;
    final authUser = authState is AuthAuthenticated ? authState.user : null;
    final normalizedRoles = authUser?.roles.map((role) => role.trim().toLowerCase()).toSet() ?? const <String>{};
    final isPublicRole = normalizedRoles.contains('publico') || normalizedRoles.contains('public') || normalizedRoles.contains('público');
    final hasAuthenticatedSession = authUser != null && !isPublicRole;
    final effectiveAdmin = hasAuthenticatedSession && (isAdmin || normalizedRoles.contains('admin') || normalizedRoles.contains('admin_liga'));
    // Las vistas abiertas con Navigator.push no tienen GoRouterState en su subárbol.
    // Por eso el contexto de cada pantalla se expresa mediante selectedIndex.
    final routeSelectedIndex = selectedIndex;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface, // Color de fondo de la barra de navegación inferior según el tema actual
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant, // Color de la línea superior de la barra de navegación inferior según el tema actual
            width: 1, // Ancho de la línea superior de la barra de navegación inferior
          ),
        ),
      ),
      child: SafeArea(
        child: BottomNavigationBar(
          currentIndex: _safeSelectedIndex(routeSelectedIndex, hasAuthenticatedSession, effectiveAdmin), // Índice válido para los elementos visibles
          onTap: (index) { // Callback que se ejecuta cuando se toca un elemento de la barra de navegación inferior
            if (onTap != null) { 
              onTap!(index);  // Si se proporcionó un callback `onTap`, lo llamamos con el índice del elemento tocado y salimos de la función para no ejecutar la navegación por defecto.
              return; 
            }

            switch (index) { // Navegación por defecto a las rutas definidas en `RouteNames` según el índice del elemento tocado en la barra de navegación inferior
              case 0:
                GoRouter.of(context).go(RouteNames.home);
                break;
              case 1:
                GoRouter.of(context).go(RouteNames.calendar);
                break;
              case 2:
                if (effectiveAdmin) {
                  GoRouter.of(context).go(RouteNames.referees);
                } else {
                  context.go(hasAuthenticatedSession ? RouteNames.profile : RouteNames.login);
                }
                break;
              case 3:
                if (effectiveAdmin) context.go(RouteNames.profile);
                break;
            }
          },
          type: BottomNavigationBarType.fixed, // Tipo de barra de navegación inferior fija, que muestra todos los elementos sin desplazamiento
          showSelectedLabels: true, // Muestra las etiquetas de los elementos seleccionados en la barra de navegación inferior
          showUnselectedLabels: true, // Muestra las etiquetas de los elementos no seleccionados en la barra de navegación inferior
          selectedItemColor: colorScheme.primary, // Color del ícono y la etiqueta del elemento seleccionado en la barra de navegación inferior según el tema actual
          unselectedItemColor: colorScheme.onSurfaceVariant, // Color del ícono y la etiqueta de los elementos no seleccionados en la barra de navegación inferior según el tema actual
          backgroundColor: colorScheme.surface, // Color de fondo de la barra de navegación inferior según el tema actual
          elevation: 0, // Elevación de la barra de navegación inferior (0 = sin sombra)
          // La navegación pública no expone Perfil; después del login se
          // reemplaza el acceso de sesión por Perfil.
          items: hasAuthenticatedSession
              ? [
                  const BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
                  const BottomNavigationBarItem(icon: Icon(Icons.calendar_month_rounded), label: 'Calendario'),
                  if (effectiveAdmin) const BottomNavigationBarItem(icon: Icon(Icons.sports_outlined), label: 'Árbitros'),
                  const BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Perfil'),
                ]
              : [
                  const BottomNavigationBarItem(
                    icon: Icon(Icons.home_rounded),
                    label: 'Home',
                  ),
                  const BottomNavigationBarItem(
                    icon: Icon(Icons.calendar_month_rounded),
                    label: 'Calendario',
                  ),
                  const BottomNavigationBarItem(
                    icon: Icon(Icons.login_rounded),
                    label: 'Iniciar sesión',
                  ),
                ],
        ),
      ),
    );
  }
}
