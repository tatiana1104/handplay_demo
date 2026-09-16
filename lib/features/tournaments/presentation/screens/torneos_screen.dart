import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/widgets/app_bottom_navigation_bar.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../../auth/presentation/bloc/auth_state.dart';

// Esta es la pantalla "Inicio" que ve cualquier persona autenticada
// (RouteNames.home). Según el mockup "Mis torneos": lista de torneos
// separados en pestañas Activos/Finalizados, cada uno con una barra de
// progreso de jornada (ej. "J7/9") y el próximo partido programado.
// El ícono de estrella (★/☆) marca/desmarca un torneo como favorito
// (RF-04, UC-10).
//
// TODO(Sprint 2): reemplazar el cuerpo por la lista real de torneos
// (RF-03), con:
// - `TorneosBloc` que pida a Firestore los torneos donde el usuario
//   tiene algún rol relevante (o todos, si es espectador).
// - Filtro por pestañas Activos/Finalizados.
// - Toggle de favorito por torneo (RF-04).
//
// Por ahora, esta pantalla también sirve como comprobante visual de
// que AuthBloc + Firebase Auth + Google Sign-In quedaron conectados:
// muestra el correo de la sesión activa y un botón para cerrar sesión.
class TorneosScreen extends StatelessWidget {
  const TorneosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis torneos'),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => context.read<AuthBloc>().add(const AuthLogoutRequested()),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: BlocBuilder<AuthBloc, AuthState>(
            builder: (context, state) {
              final email =
                  state is AuthAuthenticated ? (state.user.email ?? state.user.uid) : null;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_rounded, size: 48, color: Color(0xFF0D8932)),
                  const SizedBox(height: 12),
                  Text(
                    email != null ? 'Sesión iniciada como $email' : 'Sesión iniciada',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '"Mis torneos" — pantalla pendiente de implementar (Sprint 2).',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              );
            },
          ),
        ),
      ),
      bottomNavigationBar: const AppBottomNavigationBar(),
    );
  }
}
