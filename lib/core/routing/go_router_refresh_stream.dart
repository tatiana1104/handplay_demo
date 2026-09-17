import 'dart:async';

import 'package:flutter/foundation.dart';

/// Puente entre un `Stream` (en nuestro caso, `authBloc.stream`) y
/// `Listenable`, que es lo que `GoRouter` espera en su parámetro
/// `refreshListenable`. Cada vez que el BLoC de auth emite un nuevo
/// estado, esto notifica a `GoRouter` para que vuelva a evaluar la
/// función `redirect` (ver `main.dart`) — así, por ejemplo, un login
/// exitoso saca automáticamente al usuario de la pantalla de login sin
/// que la UI tenga que llamar `context.go()` a mano.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
