import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/usecases/cancellation_token.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/notifications/push_notification_service.dart';
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
    required void Function(PushNotificationService service) onService,
    required ProviderContainer container,
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

  group('PushNotificationService achievement foreground banner', () {
    late ProviderContainer container;
    late GlobalKey<NavigatorState> navigatorKey;
    late PushNotificationService service;

    setUp(() {
      container = ProviderContainer(
        overrides: [
          notificationsRepositoryProvider.overrideWithValue(
            _FakeNotificationsRepository(),
          ),
        ],
      );
      navigatorKey = GlobalKey<NavigatorState>();
    });

    tearDown(() {
      container.dispose();
    });

    testWidgets('shows a dedicated achievement banner and updates unread count',
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
            'type': 'achievement_unlocked',
            'achievement_id': '42',
            'achievement_name': 'Primer Paso',
            'tier': 'GOLD',
            'points': '25',
          },
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('achievement-unlocked-snackbar')),
          findsOneWidget);
      expect(find.text('Nuevo logro en tu camino'), findsOneWidget);
      expect(find.text('Primer Paso'), findsOneWidget);
      expect(find.text('GOLD · 25 pts'), findsOneWidget);
      expect(find.text('Ver logro'), findsOneWidget);
      expect(container.read(unreadNotificationsCountProvider), 1);
    });

    testWidgets('falls back to generic achievement text when name is absent',
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
            'type': 'achievement_unlocked',
            'achievement_id': '42',
          },
        ),
      );
      await tester.pump();

      expect(find.text('Nuevo logro'), findsOneWidget);
    });

    test('routes to achievement detail when achievement_id is available', () {
      final testRefProvider = Provider((ref) => ref);
      final service = PushNotificationService(
        dio: Dio(),
        ref: container.read(testRefProvider),
        navigatorKey: navigatorKey,
      );

      expect(
        service.achievementRouteForTesting({'achievement_id': '42'}),
        RouteNames.achievementDetailPath(42),
      );
    });

    test('routes to achievements list when achievement_id is missing', () {
      final testRefProvider = Provider((ref) => ref);
      final service = PushNotificationService(
        dio: Dio(),
        ref: container.read(testRefProvider),
        navigatorKey: navigatorKey,
      );

      expect(
        service.achievementRouteForTesting({}),
        RouteNames.homeAchievements,
      );
    });
  });
}
