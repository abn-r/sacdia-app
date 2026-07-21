import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/animations/page_transitions.dart';

typedef _TransitionsBuilder = Widget Function(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
);

Future<void> _pumpTransition(
  WidgetTester tester, {
  required _TransitionsBuilder builder,
  required bool disableAnimations,
  double animationValue = 0.1,
  double secondaryAnimationValue = 0.1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: Builder(
          builder: (context) => KeyedSubtree(
            key: const ValueKey('transition-under-test'),
            child: builder(
              context,
              AlwaysStoppedAnimation(animationValue),
              AlwaysStoppedAnimation(secondaryAnimationValue),
              const ColoredBox(color: Colors.blue),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void _expectSharedAxisIntermediateState() {
  final root = find.byKey(const ValueKey('transition-under-test'));
  final slides = find
      .descendant(of: root, matching: find.byType(SlideTransition))
      .evaluate()
      .map((element) => element.widget as SlideTransition)
      .toList();
  final fades = find
      .descendant(of: root, matching: find.byType(FadeTransition))
      .evaluate()
      .map((element) => element.widget as FadeTransition)
      .toList();
  final curvedValue = SacMotion.easeOut.transform(0.1);

  expect(slides, hasLength(2));
  expect(slides[0].position.value.dx, closeTo(-0.03 * curvedValue, 0.000001));
  expect(
    slides[1].position.value.dx,
    closeTo(0.04 * (1 - curvedValue), 0.000001),
  );
  expect(fades, hasLength(2));
  expect(fades[0].opacity.value, closeTo(1 - curvedValue, 0.000001));
  expect(fades[1].opacity.value, closeTo(curvedValue, 0.000001));
}

void _expectReducedSharedAxisIntermediateState() {
  final root = find.byKey(const ValueKey('transition-under-test'));
  final slides = find
      .descendant(of: root, matching: find.byType(SlideTransition))
      .evaluate()
      .map((element) => element.widget as SlideTransition)
      .toList();
  final fades = find
      .descendant(of: root, matching: find.byType(FadeTransition))
      .evaluate()
      .map((element) => element.widget as FadeTransition)
      .toList();

  expect(slides, hasLength(2));
  for (final slide in slides) {
    expect(slide.position.value, Offset.zero);
  }
  expect(fades, hasLength(2));
  expect(fades[0].opacity.value, inExclusiveRange(0, 1));
  expect(fades[1].opacity.value, inExclusiveRange(0, 1));
}

void main() {
  group('sharedAxisPage', () {
    late CustomTransitionPage<void> page;

    setUp(() {
      page = sharedAxisPage<void>(
        key: const ValueKey('shared-axis'),
        child: const SizedBox(),
      );
    });

    test('uses the route motion durations', () {
      expect(page.transitionDuration, SacMotion.routeEnter);
      expect(page.reverseTransitionDuration, SacMotion.routeExit);
    });

    testWidgets('moves and fades both pages with the ease-out curve', (
      tester,
    ) async {
      await _pumpTransition(tester,
          builder: page.transitionsBuilder, disableAnimations: false);

      _expectSharedAxisIntermediateState();
    });

    testWidgets('keeps opacity feedback but removes all reduced-motion travel',
        (
      tester,
    ) async {
      await _pumpTransition(tester,
          builder: page.transitionsBuilder, disableAnimations: true);

      _expectReducedSharedAxisIntermediateState();
    });
  });

  group('SacSharedAxisRoute', () {
    late SacSharedAxisRoute<void> route;

    setUp(() {
      route = SacSharedAxisRoute<void>(builder: (_) => const SizedBox());
    });

    test('uses the route motion durations', () {
      expect(route.transitionDuration, SacMotion.routeEnter);
      expect(route.reverseTransitionDuration, SacMotion.routeExit);
    });

    testWidgets('moves and fades both pages with the ease-out curve', (
      tester,
    ) async {
      await _pumpTransition(tester,
          builder: route.transitionsBuilder, disableAnimations: false);

      _expectSharedAxisIntermediateState();
    });

    testWidgets('keeps opacity feedback but removes all reduced-motion travel',
        (
      tester,
    ) async {
      await _pumpTransition(tester,
          builder: route.transitionsBuilder, disableAnimations: true);

      _expectReducedSharedAxisIntermediateState();
    });
  });
}
