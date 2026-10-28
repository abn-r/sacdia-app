import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/config/route_not_found_view.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';

void main() {
  testWidgets(
      'an unknown link shows the friendly page, hides the location and goes '
      'to splash', (tester) async {
    final router = GoRouter(
      initialLocation: '/certificate-import-typo/abc?t=secret-token',
      errorBuilder: (context, state) => const RouteNotFoundView(),
      routes: [
        GoRoute(
          path: RouteNames.splash,
          builder: (_, __) => const Text('splash-screen'),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
    );
    await tester.pumpAndSettle();

    // Without EasyLocalization the keys render as-is.
    expect(find.text('router.not_found.title'), findsOneWidget);
    expect(find.textContaining('secret-token'), findsNothing);
    expect(find.textContaining('GoException'), findsNothing);

    await tester.tap(find.text('router.not_found.action'));
    await tester.pumpAndSettle();
    expect(find.text('splash-screen'), findsOneWidget);
  });
}
