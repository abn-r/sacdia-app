import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/features/family/presentation/views/add_dependent_view.dart';

import 'family_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initLocalization);

  Future<void> pumpOnPhone(
    WidgetTester tester, {
    required double bottomInset,
  }) async {
    // Phone with a home indicator: 390x844 logical, 3x.
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.padding = FakeViewPadding(top: 47 * 3, bottom: bottomInset * 3);
    tester.view.viewPadding =
        FakeViewPadding(top: 47 * 3, bottom: bottomInset * 3);
    addTearDown(tester.view.reset);

    await pumpFamilyApp(
      tester,
      overrides: familyOverrides(
        repo: FakeFamilyRepository(),
        auth: FakeAuthNotifier(),
      ),
      routes: [
        GoRoute(path: '/', builder: (_, __) => const AddDependentView()),
      ],
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
      'the submit button ends above the home indicator with breathing room '
      'once the form is scrolled to the end', (tester) async {
    const inset = 34.0;
    await pumpOnPhone(tester, bottomInset: inset);

    await tester.drag(find.byType(Scrollable).first, const Offset(0, -3000));
    await tester.pumpAndSettle();

    final screenHeight = tester.view.physicalSize.height / 3;
    final bottom = tester.getBottomLeft(find.byType(SacButton)).dy;
    expect(
      bottom,
      lessThanOrEqualTo(screenHeight - inset - 24),
      reason: 'the button must clear the bottom safe area plus a margin',
    );
  });

  testWidgets('the same holds on a device without a home indicator',
      (tester) async {
    await pumpOnPhone(tester, bottomInset: 0);

    await tester.drag(find.byType(Scrollable).first, const Offset(0, -3000));
    await tester.pumpAndSettle();

    final screenHeight = tester.view.physicalSize.height / 3;
    final bottom = tester.getBottomLeft(find.byType(SacButton)).dy;
    expect(bottom, lessThanOrEqualTo(screenHeight - 16));
  });

  testWidgets('with the keyboard open the button is still reachable',
      (tester) async {
    await pumpOnPhone(tester, bottomInset: 34);
    tester.view.viewInsets = const FakeViewPadding(bottom: 336 * 3);
    await tester.pumpAndSettle();

    await tester.drag(find.byType(Scrollable).first, const Offset(0, -3000));
    await tester.pumpAndSettle();

    final screenHeight = tester.view.physicalSize.height / 3;
    final bottom = tester.getBottomLeft(find.byType(SacButton)).dy;
    expect(bottom, lessThanOrEqualTo(screenHeight - 336 - 16));
  });
}
