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

Future<void> _pumpFade(
  WidgetTester tester, {
  required _TransitionsBuilder builder,
  required bool disableAnimations,
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
              const AlwaysStoppedAnimation(0.1),
              const AlwaysStoppedAnimation(0.1),
              const ColoredBox(color: Colors.blue),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void _expectOpacityOnlyFade() {
  final root = find.byKey(const ValueKey('transition-under-test'));
  final fadeFinder = find.descendant(
    of: root,
    matching: find.byType(FadeTransition),
  );
  expect(fadeFinder, findsOne);
  expect(
    find.descendant(of: root, matching: find.byType(SlideTransition)),
    findsNothing,
  );
  expect(
    find.descendant(of: root, matching: find.byType(ScaleTransition)),
    findsNothing,
  );

  final fade = testerWidget<FadeTransition>(fadeFinder);
  expect(
      fade.opacity.value, closeTo(SacMotion.easeOut.transform(0.1), 0.000001));
}

T testerWidget<T extends Widget>(Finder finder) {
  return finder.evaluate().single.widget as T;
}

void main() {
  group('fadeThroughPage', () {
    late CustomTransitionPage<void> page;

    setUp(() {
      page = fadeThroughPage<void>(
        key: const ValueKey('fade-through'),
        child: const SizedBox(),
      );
    });

    test('uses the reduced fade duration in both directions', () {
      expect(page.transitionDuration, SacMotion.reducedFade);
      expect(page.reverseTransitionDuration, SacMotion.reducedFade);
    });

    for (final disableAnimations in [false, true]) {
      testWidgets(
        'is opacity-only when disableAnimations is $disableAnimations',
        (tester) async {
          await _pumpFade(
            tester,
            builder: page.transitionsBuilder,
            disableAnimations: disableAnimations,
          );

          _expectOpacityOnlyFade();
        },
      );
    }
  });

  group('SacFadeThroughRoute', () {
    late SacFadeThroughRoute<void> route;

    setUp(() {
      route = SacFadeThroughRoute<void>(builder: (_) => const SizedBox());
    });

    test('uses the reduced fade duration in both directions', () {
      expect(route.transitionDuration, SacMotion.reducedFade);
      expect(route.reverseTransitionDuration, SacMotion.reducedFade);
    });

    for (final disableAnimations in [false, true]) {
      testWidgets(
        'is opacity-only when disableAnimations is $disableAnimations',
        (tester) async {
          await _pumpFade(
            tester,
            builder: route.transitionsBuilder,
            disableAnimations: disableAnimations,
          );

          _expectOpacityOnlyFade();
        },
      );
    }
  });
}
