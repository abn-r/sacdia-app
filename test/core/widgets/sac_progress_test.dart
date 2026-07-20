import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/widgets/sac_progress_bar.dart';
import 'package:sacdia_app/core/widgets/sac_progress_ring.dart';

void main() {
  group('SacProgressBar', () {
    testWidgets(
        'initial reduced state paints the current target without shimmer', (
      tester,
    ) async {
      final reduceMotion = ValueNotifier<bool>(true);
      final target = ValueNotifier<double>(0.75);
      addTearDown(reduceMotion.dispose);
      addTearDown(target.dispose);

      await tester.pumpWidget(
        _ProgressHarness(
          reduceMotion: reduceMotion,
          target: target,
          builder: (progress) => SacProgressBar(
            progress: progress,
            showShimmer: true,
          ),
        ),
      );

      expect(_barFractions(tester), [0.75]);
    });

    testWidgets('runtime toggle settles progress and later changes can animate',
        (
      tester,
    ) async {
      final reduceMotion = ValueNotifier<bool>(false);
      final target = ValueNotifier<double>(0.8);
      addTearDown(reduceMotion.dispose);
      addTearDown(target.dispose);

      await tester.pumpWidget(
        _ProgressHarness(
          reduceMotion: reduceMotion,
          target: target,
          builder: (progress) => SacProgressBar(
            progress: progress,
            fillDuration: const Duration(milliseconds: 200),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(_barFractions(tester).single, inExclusiveRange(0, 0.8));

      reduceMotion.value = true;
      await tester.pump();
      expect(_barFractions(tester), [0.8]);

      target.value = 0.5;
      await tester.pump();
      expect(_barFractions(tester), [0.5]);

      reduceMotion.value = false;
      await tester.pump();
      target.value = 1;
      await tester.pump();
      expect(_barFractions(tester), [0.5]);
      await tester.pump(const Duration(milliseconds: 100));
      expect(_barFractions(tester).single, inExclusiveRange(0.5, 1));
    });
  });

  group('SacProgressRing', () {
    testWidgets('initial reduced state exposes the current target immediately',
        (
      tester,
    ) async {
      final reduceMotion = ValueNotifier<bool>(true);
      final target = ValueNotifier<double>(0.75);
      addTearDown(reduceMotion.dispose);
      addTearDown(target.dispose);

      await tester.pumpWidget(
        _ProgressHarness(
          reduceMotion: reduceMotion,
          target: target,
          builder: (progress) => SacProgressRing(progress: progress),
        ),
      );

      expect(_ringAnimation(tester).value, 0.75);
    });

    testWidgets('runtime toggle settles ring and later changes can animate', (
      tester,
    ) async {
      final reduceMotion = ValueNotifier<bool>(false);
      final target = ValueNotifier<double>(0.8);
      addTearDown(reduceMotion.dispose);
      addTearDown(target.dispose);

      await tester.pumpWidget(
        _ProgressHarness(
          reduceMotion: reduceMotion,
          target: target,
          builder: (progress) => SacProgressRing(
            progress: progress,
            animationDuration: const Duration(milliseconds: 200),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump(const Duration(milliseconds: 50));
      expect(_ringAnimation(tester).value, inExclusiveRange(0, 0.8));

      reduceMotion.value = true;
      await tester.pump();
      expect(_ringAnimation(tester).value, 0.8);

      target.value = 0.5;
      await tester.pump();
      expect(_ringAnimation(tester).value, 0.5);

      reduceMotion.value = false;
      await tester.pump();
      target.value = 1;
      await tester.pump();
      expect(_ringAnimation(tester).value, 0.5);
      await tester.pump(const Duration(milliseconds: 100));
      expect(_ringAnimation(tester).value, inExclusiveRange(0.5, 1));
    });
  });
}

List<double?> _barFractions(WidgetTester tester) => tester
    .widgetList<FractionallySizedBox>(
      find.descendant(
        of: find.byType(SacProgressBar),
        matching: find.byType(FractionallySizedBox),
      ),
    )
    .map((widget) => widget.widthFactor)
    .toList();

Animation<double> _ringAnimation(WidgetTester tester) {
  final builder = tester.widget<AnimatedBuilder>(
    find.descendant(
      of: find.byType(SacProgressRing),
      matching: find.byType(AnimatedBuilder),
    ),
  );
  return builder.animation as Animation<double>;
}

class _ProgressHarness extends StatelessWidget {
  const _ProgressHarness({
    required this.reduceMotion,
    required this.target,
    required this.builder,
  });

  final ValueListenable<bool> reduceMotion;
  final ValueListenable<double> target;
  final Widget Function(double progress) builder;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: reduceMotion,
      builder: (context, disabled, _) => MediaQuery(
        data: MediaQueryData(disableAnimations: disabled),
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 240,
                child: ValueListenableBuilder<double>(
                  valueListenable: target,
                  builder: (context, value, _) => builder(value),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
