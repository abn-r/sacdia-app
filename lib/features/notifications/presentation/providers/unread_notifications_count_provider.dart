import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../notifications/domain/repositories/notifications_repository.dart';
import 'notifications_providers.dart';

/// Notifier persistente (keepAlive) para el contador de notificaciones no leídas.
///
/// Estado: entero con el número actual de entregas no leídas del usuario.
/// Sobrevive a la navegación y sólo se destruye al hacer sign-out.
///
/// Uso:
/// ```dart
/// // Leer el conteo actual
/// final count = ref.watch(unreadNotificationsCountProvider);
///
/// // Acciones
/// ref.read(unreadNotificationsCountProvider.notifier).refresh();
/// ref.read(unreadNotificationsCountProvider.notifier).increment();
/// ref.read(unreadNotificationsCountProvider.notifier).decrement();
/// ref.read(unreadNotificationsCountProvider.notifier).setZero();
/// ```
class UnreadNotificationsCountNotifier extends Notifier<int> {
  NotificationsRepository get _repository =>
      ref.read(notificationsRepositoryProvider);

  @override
  int build() {
    return 0;
  }

  /// Consulta el backend y actualiza el estado con el conteo real.
  Future<void> refresh() async {
    final result = await _repository.getUnreadCount();
    result.fold(
      (_) {
        // En caso de error dejamos el estado actual intacto.
      },
      (count) => state = count,
    );
  }

  /// Incremento optimista al recibir una notificación push en foreground.
  void increment() => state = state + 1;

  /// Decremento optimista al marcar una notificación como leída.
  void decrement() => state = max(0, state - 1);

  /// Resetea a cero (usada en logout o al marcar todas como leídas).
  void setZero() => state = 0;
}

final unreadNotificationsCountProvider =
    NotifierProvider<UnreadNotificationsCountNotifier, int>(
  UnreadNotificationsCountNotifier.new,
);
