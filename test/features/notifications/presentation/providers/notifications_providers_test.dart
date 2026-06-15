import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/usecases/cancellation_token.dart';
import 'package:sacdia_app/features/notifications/domain/entities/notification_item.dart';
import 'package:sacdia_app/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:sacdia_app/features/notifications/presentation/providers/notifications_providers.dart';

class _SupersededHistoryRepository implements NotificationsRepository {
  final firstStarted = Completer<void>();
  int historyCalls = 0;

  @override
  Future<
          Either<Failure,
              ({List<NotificationItem> items, int total, int totalPages})>>
      getHistory({
    int page = 1,
    int limit = 20,
    RequestCancelToken? cancelToken,
  }) async {
    historyCalls += 1;

    if (historyCalls == 1) {
      firstStarted.complete();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      return left(
        const UnexpectedFailure(
          message: 'cancelled request should be ignored',
        ),
      );
    }

    return right((
      items: [
        NotificationItem(
          logId: historyCalls,
          title: 'Fresh notification',
          body: 'Latest request wins',
          type: 'USER',
          targetType: NotificationTargetType.direct,
          sentBy: 'system',
          tokensSent: 1,
          tokensFailed: 0,
          createdAt: DateTime(2026, 6, 15),
          deliveryId: 'delivery-$historyCalls',
        ),
      ],
      total: 1,
      totalPages: 1,
    ));
  }

  @override
  Future<Either<Failure, int>> getUnreadCount() async => right(0);

  @override
  Future<Either<Failure, void>> markAsRead(String deliveryId) async =>
      right(null);

  @override
  Future<Either<Failure, int>> markAllAsRead() async => right(0);
}

void main() {
  test('ignores a superseded history request instead of surfacing an error',
      () async {
    final repository = _SupersededHistoryRepository();
    final container = ProviderContainer(
      overrides: [
        notificationsRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    container.read(notificationsInboxProvider);
    await repository.firstStarted.future;

    await container.read(notificationsInboxProvider.notifier).loadNextPage();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final state = container.read(notificationsInboxProvider);
    expect(state.errorMessage, isNull);
    expect(state.items.single.title, 'Fresh notification');
  });
}
