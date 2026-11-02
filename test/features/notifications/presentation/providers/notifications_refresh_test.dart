// S5.2: la bandeja y el contador de no leídas siguen refrescándose bajo
// Riverpod 3. `NotificationsInboxState` no define `==`, así que cada `copyWith`
// notifica; el contador es un `int` y dos valores iguales NO notifican (igual
// que en 2.6).
import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/usecases/cancellation_token.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/notifications/domain/entities/notification_item.dart';
import 'package:sacdia_app/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:sacdia_app/features/notifications/presentation/providers/notifications_providers.dart';
import 'package:sacdia_app/features/notifications/presentation/providers/unread_notifications_count_provider.dart';

import '../../../../support/riverpod_test_support.dart';

NotificationItem _item(int id, {bool isRead = false}) => NotificationItem(
      logId: id,
      title: 'n$id',
      body: 'body',
      type: 'USER',
      targetType: NotificationTargetType.direct,
      sentBy: 'system',
      tokensSent: 1,
      tokensFailed: 0,
      createdAt: DateTime(2026, 6, 15),
      deliveryId: 'delivery-$id',
      isRead: isRead,
    );

class _Repo implements NotificationsRepository {
  List<NotificationItem> history = [_item(1), _item(2)];
  int unread = 2;
  int historyCalls = 0;
  int markAsReadCalls = 0;

  @override
  Future<
          Either<Failure,
              ({List<NotificationItem> items, int total, int totalPages})>>
      getHistory({
    int page = 1,
    int limit = 20,
    RequestCancelToken? cancelToken,
  }) async {
    historyCalls++;
    return right((items: history, total: history.length, totalPages: 1));
  }

  @override
  Future<Either<Failure, int>> getUnreadCount() async => right(unread);

  @override
  Future<Either<Failure, void>> markAsRead(String deliveryId) async {
    markAsReadCalls++;
    return right(null);
  }

  @override
  Future<Either<Failure, int>> markAllAsRead() async => right(0);
}

class _FakeAuth extends AuthNotifier {
  @override
  Future<UserEntity?> build() async => null;
}

void main() {
  late _Repo repo;
  late ProviderContainer container;

  setUp(() {
    repo = _Repo();
    container = createTestContainer(
      overrides: [
        notificationsRepositoryProvider.overrideWithValue(repo),
        authNotifierProvider.overrideWith(_FakeAuth.new),
      ],
    );
  });

  group('notifications inbox', () {
    test('first read loads the page, then refresh() reloads it and notifies',
        () async {
      final states = <NotificationsInboxState>[];
      container.listen(
        notificationsInboxProvider,
        (_, next) => states.add(next),
        fireImmediately: true,
      );
      expect(states.single.isLoading, isTrue);

      await pumpEventQueue();
      expect(states.last.isLoading, isFalse);
      expect(states.last.items.map((i) => i.logId), [1, 2]);

      repo.history = [_item(3)];
      states.clear();
      await container.read(notificationsInboxProvider.notifier).refresh();

      // Dos notificaciones distintas: cargando y datos nuevos.
      expect(states.first.isLoading, isTrue);
      expect(states.last.isLoading, isFalse);
      expect(states.last.items.map((i) => i.logId), [3]);
      expect(repo.historyCalls, 2);
    });

    test('markAsRead updates the item, notifies and drops the unread count',
        () async {
      container.read(unreadNotificationsCountProvider.notifier).state = 2;
      final states = <NotificationsInboxState>[];
      container.listen(notificationsInboxProvider, (_, n) => states.add(n));
      await pumpEventQueue();
      states.clear();

      await container
          .read(notificationsInboxProvider.notifier)
          .markAsRead('delivery-1');

      expect(states, isNotEmpty);
      final items = container.read(notificationsInboxProvider).items;
      expect(items.firstWhere((i) => i.logId == 1).isRead, isTrue);
      expect(items.firstWhere((i) => i.logId == 2).isRead, isFalse);
      expect(container.read(unreadNotificationsCountProvider), 1);
      expect(repo.markAsReadCalls, 1);
    });

    test('an inbox state with identical content still notifies (no ==)', () {
      var notifications = 0;
      container.listen(notificationsInboxProvider, (_, __) => notifications++);

      // Se asigna una copia estructuralmente igual: sin `==`, es otro objeto.
      final notifier = container.read(notificationsInboxProvider.notifier);
      notifier.state = notifier.state.copyWith();
      notifier.state = notifier.state.copyWith();

      expect(notifications, 2);
    });
  });

  group('unread count', () {
    test('refresh() takes the server value and notifies the listener',
        () async {
      final seen = <int>[];
      container.listen(unreadNotificationsCountProvider, (_, n) => seen.add(n));

      await container.read(unreadNotificationsCountProvider.notifier).refresh();

      expect(container.read(unreadNotificationsCountProvider), 2);
      expect(seen, [2]);
    });

    test('an equal count does not notify (int ==, same as 2.6)', () async {
      final notifier =
          container.read(unreadNotificationsCountProvider.notifier);
      await notifier.refresh();
      final seen = <int>[];
      container.listen(unreadNotificationsCountProvider, (_, n) => seen.add(n));

      await notifier.refresh(); // el servidor sigue diciendo 2
      expect(seen, isEmpty);

      repo.unread = 5;
      await notifier.refresh();
      expect(seen, [5]);
    });
  });
}
