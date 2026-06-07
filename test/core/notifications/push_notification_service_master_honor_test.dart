import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/notifications/push_notification_service.dart';
import 'package:sacdia_app/core/usecases/cancellation_token.dart';
import 'package:sacdia_app/features/master_honors/presentation/providers/master_honor_modal_queue_provider.dart';
import 'package:sacdia_app/features/master_honors/presentation/providers/master_honors_providers.dart';
import 'package:sacdia_app/features/notifications/domain/entities/notification_item.dart';
import 'package:sacdia_app/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:sacdia_app/features/notifications/presentation/providers/notifications_providers.dart';
import 'package:sacdia_app/features/notifications/presentation/providers/unread_notifications_count_provider.dart';

class _FakeNotificationsRepository implements NotificationsRepository {
  @override
  Future<
          Either<Failure,
              ({List<NotificationItem> items, int total, int totalPages})>>
      getHistory({
    int page = 1,
    int limit = 20,
    RequestCancelToken? cancelToken,
  }) async {
    return right((items: <NotificationItem>[], total: 0, totalPages: 1));
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
  Widget buildHarness({
    required GlobalKey<NavigatorState> navigatorKey,
    required ProviderContainer container,
    required void Function(PushNotificationService service) onService,
  }) {
    final pushNotificationServiceProvider =
        Provider<PushNotificationService>((ref) {
      return PushNotificationService(
        dio: Dio(),
        ref: ref,
        navigatorKey: navigatorKey,
      );
    });

    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        navigatorKey: navigatorKey,
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) {
              onService(ref.read(pushNotificationServiceProvider));
              return const Text('Home');
            },
          ),
        ),
      ),
    );
  }

  group('PushNotificationService master honor changes', () {
    late ProviderContainer container;
    late GlobalKey<NavigatorState> navigatorKey;
    late PushNotificationService service;
    late _FakeNotificationsRepository repository;
    late int masterHonorInvalidations;

    setUp(() {
      repository = _FakeNotificationsRepository();
      navigatorKey = GlobalKey<NavigatorState>();
      masterHonorInvalidations = 0;
      container = ProviderContainer(
        overrides: [
          notificationsRepositoryProvider.overrideWithValue(repository),
          masterHonorsInvalidationProvider.overrideWithValue(
            () => masterHonorInvalidations++,
          ),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    testWidgets(
      'foreground payload updates notification state and queues one grouped modal event',
      (tester) async {
        await tester.pumpWidget(
          buildHarness(
            navigatorKey: navigatorKey,
            container: container,
            onService: (created) => service = created,
          ),
        );

        service.handleForegroundMessageForTesting(
          RemoteMessage(
            data: const {
              'type': 'master_honor_changed',
              'transition': 'not_current',
              'master_honor_ids': '1,2',
              'master_honor_names':
                  'Maestría en Acuática|Maestría en Artesanía',
            },
          ),
        );
        await tester.pump();

        expect(container.read(unreadNotificationsCountProvider), 1);
        expect(masterHonorInvalidations, 1);

        final queue = container.read(masterHonorModalQueueProvider);
        expect(queue, hasLength(1));
        expect(queue.single.transition, MasterHonorChangeTransition.notCurrent);
        expect(
          queue.single.masterHonorNames,
          ['Maestría en Acuática', 'Maestría en Artesanía'],
        );
        expect(find.text('Maestrías marcadas como No vigente'), findsOneWidget);

        await tester.tap(find.text('Entendido'));
        await tester.pumpAndSettle();
        expect(container.read(masterHonorModalQueueProvider), isEmpty);
      },
    );

    test('master honor notification tap routes to profile', () {
      final testRefProvider = Provider((ref) => ref);
      final service = PushNotificationService(
        dio: Dio(),
        ref: container.read(testRefProvider),
        navigatorKey: navigatorKey,
      );

      final route = service.masterHonorChangedRouteForTesting({});

      expect(route, RouteNames.homeProfile);
      expect(service.usesGoNavigationForTesting(route), isTrue);
    });
  });
}
