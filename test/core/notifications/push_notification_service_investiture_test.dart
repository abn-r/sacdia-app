import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/notifications/push_notification_service.dart';

void main() {
  group('PushNotificationService investiture results', () {
    late GlobalKey<NavigatorState> navigatorKey;
    late ProviderContainer container;
    late PushNotificationService service;
    late List<String> visited;

    setUp(() {
      navigatorKey = GlobalKey<NavigatorState>();
      container = ProviderContainer();
      service = container.read(
        Provider<PushNotificationService>(
          (ref) => PushNotificationService(
            dio: Dio(),
            ref: ref,
            navigatorKey: navigatorKey,
          ),
        ),
      );
      visited = [];
    });

    tearDown(() => container.dispose());

    Future<void> pumpApp(WidgetTester tester) async {
      Page<void> stub(GoRouterState state) {
        visited.add(state.uri.toString());
        return MaterialPage<void>(
          key: state.pageKey,
          child: Scaffold(body: Text('screen ${state.uri}')),
        );
      }

      final router = GoRouter(
        navigatorKey: navigatorKey,
        initialLocation: '/start',
        routes: [
          GoRoute(
            path: '/start',
            pageBuilder: (context, state) => MaterialPage<void>(
              key: state.pageKey,
              child: const Scaffold(body: Text('start')),
            ),
          ),
          GoRoute(
            path: RouteNames.sectionInvestiture,
            pageBuilder: (context, state) => stub(state),
          ),
          GoRoute(
            path: RouteNames.ownInvestiture,
            pageBuilder: (context, state) => stub(state),
          ),
          GoRoute(
            path: RouteNames.classDetail,
            pageBuilder: (context, state) => stub(state),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();
    }

    testWidgets('board audience opens the section screen', (tester) async {
      await pumpApp(tester);

      service.handleNotificationTapForTesting(
        RemoteMessage(
          data: const {
            'type': 'investiture_result',
            'audience': 'board',
            'requestId': 'r1',
            'sectionId': '4',
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(visited, [RouteNames.sectionInvestiture]);
    });

    testWidgets('person audience with a class opens the class detail',
        (tester) async {
      await pumpApp(tester);

      service.handleNotificationTapForTesting(
        RemoteMessage(
          data: const {
            'type': 'investiture_result',
            'audience': 'person',
            'requestId': 'r1',
            'sectionId': '4',
            'classId': '3',
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(visited, ['/class/3']);
    });

    testWidgets('person audience without a class opens the own list',
        (tester) async {
      await pumpApp(tester);

      service.handleNotificationTapForTesting(
        RemoteMessage(
          data: const {
            'type': 'investiture_result',
            'audience': 'person',
            'requestId': 'r1',
            'sectionId': '4',
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(visited, [RouteNames.ownInvestiture]);
    });
  });
}
