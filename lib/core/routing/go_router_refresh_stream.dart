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
  /// ES: Notifica al router cada vez que [stream] emite un valor.
  /// EN: Notifies router listeners whenever [stream] emits a value.
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  /// ES: Cancela la escucha del stream y libera este notificador.
  /// EN: Cancels the stream listener and releases this notifier.
  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
