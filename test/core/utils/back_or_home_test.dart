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

GoRouter _router(String initialLocation) => GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: RouteNames.home,
          builder: (_, __) => const Scaffold(body: Text('dashboard')),
          routes: [
            GoRoute(path: 'units', builder: (_, __) => _backButton()),
          ],
        ),
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
    expect(
        router.routerDelegate.currentConfiguration.uri.path, RouteNames.home);
  });

  testWidgets('with a previous page it simply goes back', (tester) async {
    final router = _router(RouteNames.home);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    router.push('${RouteNames.home}/units');
    await tester.pumpAndSettle();

    await tester.tap(find.text('back'));
    await tester.pumpAndSettle();

    expect(find.text('dashboard'), findsOneWidget);
    expect(find.text('back'), findsNothing);
  });
}
