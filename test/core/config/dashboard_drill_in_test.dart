import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/config/dashboard_drill_in.dart';
import 'package:sacdia_app/core/config/route_names.dart';

/// Same shape as the app: the dashboard and its quick-access modules are
/// sibling routes of one shell branch; the inbox is a root route.
GoRouter _router() {
  final root = GlobalKey<NavigatorState>();
  return GoRouter(
    navigatorKey: root,
    initialLocation: RouteNames.homeDashboard,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => Scaffold(
          body: shell,
          bottomNavigationBar: Row(children: [
            TextButton(
              onPressed: () => shell.goBranch(0, initialLocation: true),
              child: const Text('tab-inicio'),
            ),
          ]),
        ),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: RouteNames.homeDashboard,
              builder: (_, __) => const Text('dashboard'),
            ),
            GoRoute(
              path: RouteNames.homeMembers,
              builder: (_, state) => Text('members ${state.uri}'),
            ),
          ]),
        ],
      ),
      GoRoute(
        parentNavigatorKey: root,
        path: RouteNames.notificationsInbox,
        builder: (_, __) => const Text('inbox'),
      ),
    ],
  );
}

void main() {
  test('drill-in detection covers the members requests deep link', () {
    expect(isDashboardDrillIn(RouteNames.homeMemberRequests), isTrue);
    expect(isDashboardDrillIn(RouteNames.homeMembers), isTrue);
    expect(isDashboardDrillIn(RouteNames.homeDashboard), isFalse);
    expect(isDashboardDrillIn(RouteNames.homeProfile), isFalse);
  });

  testWidgets(
      'opening Members from the inbox keeps the dashboard underneath it',
      (tester) async {
    final router = _router();
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    router.push(RouteNames.notificationsInbox);
    await tester.pumpAndSettle();
    expect(find.text('inbox'), findsOneWidget);

    final opening = openDashboardDrillIn(router, RouteNames.homeMemberRequests);
    await tester.pumpAndSettle();
    await opening;
    await tester.pumpAndSettle();

    expect(
        find.text('members ${RouteNames.homeMemberRequests}'), findsOneWidget);
    expect(find.text('inbox'), findsNothing);

    // Back returns to the dashboard instead of being stuck on Members.
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('dashboard'), findsOneWidget);
  });

  testWidgets('the Inicio tab leaves Members after opening it from the inbox',
      (tester) async {
    final router = _router();
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    router.push(RouteNames.notificationsInbox);
    await tester.pumpAndSettle();

    final opening = openDashboardDrillIn(router, RouteNames.homeMemberRequests);
    await tester.pumpAndSettle();
    await opening;
    await tester.pumpAndSettle();

    await tester.tap(find.text('tab-inicio'));
    await tester.pumpAndSettle();
    expect(find.text('dashboard'), findsOneWidget);
  });
}
