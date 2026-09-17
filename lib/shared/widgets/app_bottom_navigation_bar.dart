import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart'; // Importamos la librería `go_router` para poder navegar entre pantallas usando rutas definidas en `RouteNames`

import '../../core/routing/route_names.dart'; // Importamos los nombres de ruta de la app, como `RouteNames.home`, para poder navegar a la pantalla de inicio desde la barra de navegación inferior

class AppBottomNavigationBar extends StatelessWidget {
  final int selectedIndex; // Índice del elemento seleccionado en la barra de navegación inferior (0 = Home, 1 = Calendario, 2 = Perfil)
  final ValueChanged<int>? onTap; // Callback que se ejecuta cuando se toca un elemento de la barra de navegación inferior. Si es nulo, se usa la navegación por defecto a las rutas definidas en `RouteNames`.

  /// Constructor de la barra de navegación inferior, con parámetros opcionales `selectedIndex` y `onTap`.
  const AppBottomNavigationBar({
    super.key, 
    this.selectedIndex = 0, // Índice del elemento seleccionado en la barra de navegación inferior (0 = Home, 1 = Calendario, 2 = Perfil)
    this.onTap, // Callback que se ejecuta cuando se toca un elemento de la barra de navegación inferior. Si es nulo, se usa la navegación por defecto a las rutas definidas en `RouteNames`.
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme; // Obtenemos el esquema de colores del tema actual para usarlo en la barra de navegación inferior

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
                context.go(RouteNames.home); // Navegamos a la pantalla de inicio (lista de torneos) cuando se toca el segundo elemento (índice 1) de la barra de navegación inferior. TODO: reemplazar por la ruta del calendario cuando se implemente.
                break;
              case 2:
                context.go(RouteNames.profile); // El perfil solo está disponible después de iniciar sesión.
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
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded), // Ícono del primer elemento (Home) de la barra de navegación inferior    
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_month_rounded), // Ícono del segundo elemento (Calendario) de la barra de navegación inferior
              label: 'Calendario',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_rounded), // Ícono del tercer elemento (Perfil) de la barra de navegación inferior
              label: 'Perfil',
            ),
          ],
        ),
      ),
    );
  }
}
