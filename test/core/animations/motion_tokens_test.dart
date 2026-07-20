import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';

void main() {
  group('SacMotion', () {
    test('defines the shared curves', () {
      expect(SacMotion.easeOut, const Cubic(0.23, 1, 0.32, 1));
      expect(SacMotion.easeInOut, const Cubic(0.77, 0, 0.175, 1));
      expect(SacMotion.drawer, const Cubic(0.32, 0.72, 0, 1));
    });

    test('defines the shared durations', () {
      expect(SacMotion.press, const Duration(milliseconds: 140));
      expect(SacMotion.reducedFade, const Duration(milliseconds: 160));
      expect(SacMotion.standard, const Duration(milliseconds: 200));
      expect(SacMotion.routeEnter, const Duration(milliseconds: 240));
      expect(SacMotion.routeExit, const Duration(milliseconds: 200));
      expect(SacMotion.modal, const Duration(milliseconds: 240));
      expect(SacMotion.stagger, const Duration(milliseconds: 40));
    });

    test('defines the shared enter scale', () {
      expect(SacMotion.enterScale, 0.96);
    });

    testWidgets('reduceMotionOf returns false without MediaQuery', (
      tester,
    ) async {
      late bool reduceMotion;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (context) {
              reduceMotion = SacMotion.reduceMotionOf(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(reduceMotion, isFalse);
    });

    testWidgets('reduceMotionOf returns false when animations are enabled', (
      tester,
    ) async {
      late bool reduceMotion;

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: false),
          child: Builder(
            builder: (context) {
              reduceMotion = SacMotion.reduceMotionOf(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(reduceMotion, isFalse);
    });

    testWidgets('reduceMotionOf returns true when animations are disabled', (
      tester,
    ) async {
      late bool reduceMotion;

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Builder(
            builder: (context) {
              reduceMotion = SacMotion.reduceMotionOf(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(reduceMotion, isTrue);
    });
  });
}
