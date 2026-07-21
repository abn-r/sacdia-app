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
              const AlwaysStoppedAnimation(0),
              const ColoredBox(color: Colors.blue),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _pumpEarlyPop(
  WidgetTester tester, {
  required _TransitionsBuilder builder,
}) async {
  final controller = AnimationController(
    vsync: tester,
    duration: SacMotion.routeEnter,
    reverseDuration: SacMotion.routeExit,
    value: 1,
  );

  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => KeyedSubtree(
          key: const ValueKey('transition-under-test'),
          child: builder(
            context,
            controller,
            const AlwaysStoppedAnimation(0),
            const ColoredBox(color: Colors.blue),
          ),
        ),
      ),
    ),
  );

  controller.reverse();
  expect(controller.status, AnimationStatus.reverse);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 20));
  controller.dispose();
}

void _expectNormalSlideUp() {
  final root = find.byKey(const ValueKey('transition-under-test'));
  final slide = testerWidget<SlideTransition>(
    find.descendant(of: root, matching: find.byType(SlideTransition)),
  );
  final fade = testerWidget<FadeTransition>(
    find.descendant(of: root, matching: find.byType(FadeTransition)),
  );

  expect(slide.position.value.dx, 0);
  expect(
    slide.position.value.dy,
    closeTo(1 - SacMotion.drawer.transform(0.1), 0.000001),
  );
  expect(
      fade.opacity.value, closeTo(SacMotion.easeOut.transform(0.1), 0.000001));
}

void _expectReducedSlideUp() {
  final root = find.byKey(const ValueKey('transition-under-test'));
  final slide = testerWidget<SlideTransition>(
    find.descendant(of: root, matching: find.byType(SlideTransition)),
  );
  final fade = testerWidget<FadeTransition>(
    find.descendant(of: root, matching: find.byType(FadeTransition)),
  );

  expect(slide.position.value, Offset.zero);
  expect(fade.opacity.value, inExclusiveRange(0, 1));
}

void _expectResponsiveSlideUpPop() {
  final root = find.byKey(const ValueKey('transition-under-test'));
  final slide = testerWidget<SlideTransition>(
    find.descendant(of: root, matching: find.byType(SlideTransition)),
  );
  final fade = testerWidget<FadeTransition>(
    find.descendant(of: root, matching: find.byType(FadeTransition)),
  );

  expect(slide.position.value.dx, 0);
  expect(
    slide.position.value.dy,
    closeTo(SacMotion.drawer.transform(0.1), 0.000001),
  );
  expect(slide.position.value.dy, greaterThan(0));
  expect(
    fade.opacity.value,
    closeTo(1 - SacMotion.easeOut.transform(0.1), 0.000001),
  );
}

T testerWidget<T extends Widget>(Finder finder) {
  return finder.evaluate().single.widget as T;
}

void main() {
  group('slideUpPage', () {
    late CustomTransitionPage<void> page;

    setUp(() {
      page = slideUpPage<void>(
        key: const ValueKey('slide-up'),
        child: const SizedBox(),
      );
    });

    test('uses modal route durations', () {
      expect(page.transitionDuration, SacMotion.routeEnter);
      expect(page.reverseTransitionDuration, SacMotion.routeExit);
    });

    testWidgets('preserves full-height travel with drawer easing', (
      tester,
    ) async {
      await _pumpTransition(tester,
          builder: page.transitionsBuilder, disableAnimations: false);

      _expectNormalSlideUp();
    });

    testWidgets('uses fade feedback without reduced-motion travel', (
      tester,
    ) async {
      await _pumpTransition(tester,
          builder: page.transitionsBuilder, disableAnimations: true);

      _expectReducedSlideUp();
    });

    testWidgets('starts pop travel responsively toward the bottom', (
      tester,
    ) async {
      await _pumpEarlyPop(tester, builder: page.transitionsBuilder);

      _expectResponsiveSlideUpPop();
    });
  });

  group('SacSlideUpRoute', () {
    late SacSlideUpRoute<void> route;

    setUp(() {
      route = SacSlideUpRoute<void>(builder: (_) => const SizedBox());
    });

    test('uses modal route durations', () {
      expect(route.transitionDuration, SacMotion.routeEnter);
      expect(route.reverseTransitionDuration, SacMotion.routeExit);
    });

    testWidgets('preserves full-height travel with drawer easing', (
      tester,
    ) async {
      await _pumpTransition(tester,
          builder: route.transitionsBuilder, disableAnimations: false);

      _expectNormalSlideUp();
    });

    testWidgets('uses fade feedback without reduced-motion travel', (
      tester,
    ) async {
      await _pumpTransition(tester,
          builder: route.transitionsBuilder, disableAnimations: true);

      _expectReducedSlideUp();
    });

    testWidgets('starts pop travel responsively toward the bottom', (
      tester,
    ) async {
      await _pumpEarlyPop(tester, builder: route.transitionsBuilder);

      _expectResponsiveSlideUpPop();
    });
  });
}
