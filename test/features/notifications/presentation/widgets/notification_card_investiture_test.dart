import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/features/members/presentation/providers/members_providers.dart';
import 'package:sacdia_app/features/notifications/domain/entities/notification_item.dart';
import 'package:sacdia_app/features/notifications/presentation/widgets/notification_card.dart';

NotificationItem _notification(String? source) => NotificationItem(
      logId: 1,
      title: 'Resultado de investidura',
      body: 'Detalle de la notificación.',
      type: 'USER',
      source: source,
      targetType: NotificationTargetType.direct,
      sentBy: 'system',
      tokensSent: 1,
      tokensFailed: 0,
      createdAt: DateTime(2026, 11, 15, 10, 30),
      deliveryId: 'delivery-1',
      isRead: true,
      readAt: DateTime(2026, 11, 15, 10, 31),
    );

Future<List<String>> _pumpCard(
  WidgetTester tester, {
  required NotificationItem notification,
  String? role,
}) async {
  final visited = <String>[];
  Page<void> stub(GoRouterState state) {
    visited.add(state.matchedLocation);
    return MaterialPage<void>(
      key: state.pageKey,
      child: Scaffold(body: Text('screen ${state.matchedLocation}')),
    );
  }

  final router = GoRouter(
    initialLocation: '/inbox',
    routes: [
      GoRoute(
        path: '/inbox',
        pageBuilder: (context, state) => MaterialPage<void>(
          key: state.pageKey,
          child: Scaffold(body: NotificationCard(notification: notification)),
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
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        clubContextProvider.overrideWith(
          (ref) async => role == null
              ? null
              : ClubContext(clubId: 1, sectionId: 4, roleName: role),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pump();
  await tester.pump();
  await tester.tap(find.text('Resultado de investidura'));
  await tester.pumpAndSettle();
  return visited;
}

void main() {
  group('investiture result notifications', () {
    testWidgets('open the own investiture list for a regular member',
        (tester) async {
      final visited = await _pumpCard(
        tester,
        notification: _notification('investiture:invested'),
        role: 'counselor',
      );
      expect(visited, [RouteNames.ownInvestiture]);
      expect(find.text('screen ${RouteNames.ownInvestiture}'), findsOneWidget);
    });

    testWidgets('open the section screen for the board', (tester) async {
      final visited = await _pumpCard(
        tester,
        notification: _notification('investiture:rejected'),
        role: 'secretary',
      );
      expect(visited, [RouteNames.sectionInvestiture]);
    });

    testWidgets('keep the detail sheet for any other notification',
        (tester) async {
      final visited = await _pumpCard(
        tester,
        notification: _notification('validation:approved'),
        role: 'director',
      );
      expect(visited, isEmpty);
      expect(find.text('Detalle de la notificación.'), findsWidgets);
      expect(find.text('notifications.inbox.detail_accept'), findsOneWidget);
    });
  });
}
