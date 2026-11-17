import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/utils/back_or_home.dart';

Widget _backButton() => Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () => backOrHome(context),
          child: const Text('back'),
        ),
      ),
    );

// Same shape as the app: there is no `/home` route, only its children.
GoRouter _router(String initialLocation) => GoRouter(
      initialLocation: initialLocation,
      errorBuilder: (_, __) => const Scaffold(body: Text('not found')),
      routes: [
        GoRoute(
          path: RouteNames.homeDashboard,
          builder: (_, __) => const Scaffold(body: Text('dashboard')),
        ),
        GoRoute(path: '/home/units', builder: (_, __) => _backButton()),
        GoRoute(path: '/deep', builder: (_, __) => _backButton()),
      ],
    );

void main() {
  testWidgets('first page of the stack (deep link) goes to the dashboard',
      (tester) async {
    final router = _router('/deep');
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    await tester.tap(find.text('back'));
    await tester.pumpAndSettle();

    expect(find.text('dashboard'), findsOneWidget);
    expect(find.text('not found'), findsNothing);
    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      RouteNames.homeDashboard,
    );
  });

  testWidgets('with a previous page it simply goes back', (tester) async {
    final router = _router(RouteNames.homeDashboard);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    router.push('/home/units');
    await tester.pumpAndSettle();

    await tester.tap(find.text('back'));
    await tester.pumpAndSettle();

    expect(find.text('dashboard'), findsOneWidget);
    expect(find.text('back'), findsNothing);
  });

  testWidgets('a second tap while the page leaves does nothing more',
      (tester) async {
    final router = _router(RouteNames.homeDashboard);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    router.push('/home/units');
    await tester.pumpAndSettle();

    // Two taps on the same back button before the exit animation ends.
    final context = tester.element(find.text('back'));
    backOrHome(context);
    backOrHome(context);
    await tester.pumpAndSettle();

    expect(find.text('dashboard'), findsOneWidget);
    expect(find.text('not found'), findsNothing);
    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      RouteNames.homeDashboard,
    );
  });
}
