import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/auth/presentation/views/login_view.dart';

import '../family/family_test_harness.dart';
import 'device_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initLocalization);

  testWidgets('the sign-in screen offers "link a child\'s phone"',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await pumpFamilyApp(
      tester,
      overrides: [
        authNotifierProvider.overrideWith(() => FakeDeviceAuth(null)),
      ],
      routes: [
        GoRoute(path: '/', builder: (_, __) => const LoginView()),
        stubRoute(RouteNames.devicePair),
      ],
    );
    await tester.pump(const Duration(seconds: 1));

    final entry = find.byKey(const ValueKey('login_pair_device'));
    await tester.ensureVisible(entry);
    expect(find.text('Vincular este teléfono de un niño'), findsOneWidget);

    await tester.tap(entry);
    await tester.pumpAndSettle();

    expect(find.text('route:${RouteNames.devicePair}'), findsOneWidget);
  });
}
