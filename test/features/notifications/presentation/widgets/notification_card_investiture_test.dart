import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/features/members/presentation/providers/members_providers.dart';
import 'package:sacdia_app/features/notifications/domain/entities/notification_item.dart';
import 'package:sacdia_app/features/notifications/presentation/widgets/notification_card.dart';
import '../../../../support/riverpod_test_support.dart';
import 'package:sacdia_app/features/auth/domain/entities/authorization_snapshot.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import '../../../../support/capability_fixtures.dart';

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

UserEntity? _userFor(String? role) => role == null
    ? null
    : UserEntity(
        id: 'u1',
        email: 'u1@example.com',
        authorization: AuthorizationSnapshot(
          activeAssignmentId: 'a1',
          clubAssignments: [
            AuthorizationGrant(
              assignmentId: 'a1',
              roleName: role,
              clubId: 1,
              sectionId: 4,
              status: 'active',
            ),
          ],
          capabilities: capabilitiesFor(activeClubRole: role),
        ),
      );

class _FakeAuth extends AuthNotifier {
  _FakeAuth(this._user);

  final UserEntity? _user;

  @override
  Future<UserEntity?> build() async => _user;
}

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

  // Same shape as the app: the section screen is a sibling of the dashboard
  // inside the Inicio shell branch; the inbox and the own list are root
  // routes. Pushing a branch route over the root inbox broke the navigator.
  final root = GlobalKey<NavigatorState>();
  final router = GoRouter(
    navigatorKey: root,
    initialLocation: RouteNames.homeDashboard,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => Scaffold(body: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: RouteNames.homeDashboard,
              pageBuilder: (context, state) => MaterialPage<void>(
                key: state.pageKey,
                child: const Scaffold(body: Text('dashboard')),
              ),
            ),
            GoRoute(
              path: RouteNames.sectionInvestiture,
              pageBuilder: (context, state) => stub(state),
            ),
          ]),
        ],
      ),
      GoRoute(
        parentNavigatorKey: root,
        path: '/inbox',
        pageBuilder: (context, state) => MaterialPage<void>(
          key: state.pageKey,
          child: Scaffold(body: NotificationCard(notification: notification)),
        ),
      ),
      GoRoute(
        parentNavigatorKey: root,
        path: RouteNames.ownInvestiture,
        pageBuilder: (context, state) => stub(state),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    testProviderScope(
      overrides: [
        clubContextProvider.overrideWith(
          (ref) async => role == null
              ? null
              : ClubContext(clubId: 1, sectionId: 4, roleName: role),
        ),
        // La directiva se reconoce por `investiture.board` (del servidor).
        authNotifierProvider.overrideWith(() => _FakeAuth(_userFor(role))),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pump();
  router.push('/inbox');
  await tester.pumpAndSettle();
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
      expect(tester.takeException(), isNull);
      expect(
        find.text('screen ${RouteNames.sectionInvestiture}'),
        findsOneWidget,
      );
      // Back lands on the dashboard, not on a broken stack.
      GoRouter.of(tester.element(find.text(
        'screen ${RouteNames.sectionInvestiture}',
      ))).pop();
      await tester.pumpAndSettle();
      expect(find.text('dashboard'), findsOneWidget);
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
