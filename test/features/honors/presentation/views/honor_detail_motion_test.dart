import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/features/honors/presentation/views/honor_detail_view.dart';

void main() {
  testWidgets(
    'normal hero begins at the shared scale and settles without overshoot',
    (tester) async {
      final reduceMotion = ValueNotifier<bool>(false);
      addTearDown(reduceMotion.dispose);

      await tester.pumpWidget(_HeroMotionHarness(reduceMotion: reduceMotion));

      expect(_scale(tester).scale.value, SacMotion.enterScale);
      expect(_progress(tester).value, 0);
      expect(tester.binding.hasScheduledFrame, isTrue);

      await tester.pump(SacMotion.routeEnter ~/ 2);
      expect(_scale(tester).scale.value, inExclusiveRange(0.96, 1));
      expect(_scale(tester).scale.value, lessThanOrEqualTo(1));
      expect(_progress(tester).value, inExclusiveRange(0, 0.6));

      await tester.pump(SacMotion.routeEnter ~/ 2);
      expect(_scale(tester).scale.value, 1);
      expect(_progress(tester).value, 0.6);
    },
  );

  testWidgets('reduced motion starts the hero fully settled without frames', (
    tester,
  ) async {
    final reduceMotion = ValueNotifier<bool>(true);
    addTearDown(reduceMotion.dispose);

    await tester.pumpWidget(_HeroMotionHarness(reduceMotion: reduceMotion));

    expect(_scale(tester).scale.value, 1);
    expect(_progress(tester).value, 0.6);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets(
      'runtime reduced-motion changes settle and never replay hero entry',
      (tester) async {
    final reduceMotion = ValueNotifier<bool>(false);
    addTearDown(reduceMotion.dispose);

    await tester.pumpWidget(_HeroMotionHarness(reduceMotion: reduceMotion));
    await tester.pump(const Duration(milliseconds: 40));
    expect(_scale(tester).scale.value, inExclusiveRange(0.96, 1));
    expect(_progress(tester).value, inExclusiveRange(0, 0.6));

    reduceMotion.value = true;
    await tester.pump();

    expect(_scale(tester).scale.value, 1);
    expect(_progress(tester).value, 0.6);
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);

    reduceMotion.value = false;
    await tester.pump();

    expect(_scale(tester).scale.value, 1);
    expect(_progress(tester).value, 0.6);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}

ScaleTransition _scale(WidgetTester tester) =>
    tester.widget<ScaleTransition>(find.byType(ScaleTransition));

LinearProgressIndicator _progress(WidgetTester tester) => tester
    .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator));

class _HeroMotionHarness extends StatelessWidget {
  const _HeroMotionHarness({required this.reduceMotion});

  final ValueListenable<bool> reduceMotion;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: reduceMotion,
      builder: (context, disabled, _) => MediaQuery(
        data: MediaQueryData(disableAnimations: disabled),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: HonorHeroMotion(
            builder: (context, badgeScale, progressValue) => Column(
              children: [
                ScaleTransition(
                  scale: badgeScale,
                  child: const SizedBox(width: 40, height: 40),
                ),
                AnimatedBuilder(
                  animation: progressValue,
                  builder: (context, _) => LinearProgressIndicator(
                    value: progressValue.value * 0.6,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
