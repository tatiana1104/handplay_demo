import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/referees/presentation/screens/referees_screen.dart';
import '../../features/matches/presentation/screens/calendar_screen.dart';
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final authState = context.watch<AuthBloc>().state;
    final authUser = authState is AuthAuthenticated ? authState.user : null;
    final effectiveAdmin = isAdmin || authUser?.roles.any((role) => role == 'admin' || role == 'admin_liga') == true;

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
          currentIndex: selectedIndex, // Índice del elemento seleccionado en la barra de navegación inferior
          onTap: (index) { // Callback que se ejecuta cuando se toca un elemento de la barra de navegación inferior
            if (onTap != null) { 
              onTap!(index);  // Si se proporcionó un callback `onTap`, lo llamamos con el índice del elemento tocado y salimos de la función para no ejecutar la navegación por defecto.
              return; 
            }

            switch (index) { // Navegación por defecto a las rutas definidas en `RouteNames` según el índice del elemento tocado en la barra de navegación inferior
              case 0:
                context.go(RouteNames.home); // Navegamos a la pantalla de inicio (lista de torneos) cuando se toca el primer elemento (índice 0) de la barra de navegación inferior
                break;
              case 1:
                if (isAuthenticated) {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CalendarScreen()));
                } else {
                  context.go(RouteNames.login);
                }
                break;
              case 2:
                if (effectiveAdmin) {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RefereesScreen()));
                } else {
                  context.go(RouteNames.profile);
                }
                break;
              case 3:
                context.go(RouteNames.profile);
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
          items: isAuthenticated
              ? [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.home_rounded),
                    label: 'Home',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.calendar_month_rounded),
                    label: 'Calendario',
                  ),
                  if (effectiveAdmin)
                    BottomNavigationBarItem(
                      icon: Icon(Icons.sports_outlined),
                      label: 'Árbitros',
                    ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.person_rounded),
                    label: 'Perfil',
                  ),
                ]
              : const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.home_rounded),
                    label: 'Home',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.login_rounded),
                    label: 'Iniciar sesión',
                  ),
                ],
        ),
      ),
    );
  }
}
