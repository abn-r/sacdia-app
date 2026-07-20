import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/animations/animated_counter.dart';

void main() {
  testWidgets('shows the initial target instead of stale zero when reduced', (
    tester,
  ) async {
    final reduceMotion = ValueNotifier<bool>(true);
    final target = ValueNotifier<int>(42);
    addTearDown(reduceMotion.dispose);
    addTearDown(target.dispose);

    await tester.pumpWidget(
      _CounterHarness(
        reduceMotion: reduceMotion,
        target: target,
      ),
    );

    expect(find.text('42'), findsOneWidget);
    expect(find.text('0'), findsNothing);
  });

  testWidgets('settles on toggle and later changes animate after re-enabling', (
    tester,
  ) async {
    final reduceMotion = ValueNotifier<bool>(false);
    final target = ValueNotifier<int>(100);
    addTearDown(reduceMotion.dispose);
    addTearDown(target.dispose);

    await tester.pumpWidget(
      _CounterHarness(reduceMotion: reduceMotion, target: target),
    );
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 50));

    expect(_displayedValue(tester), inExclusiveRange(0, 100));

    reduceMotion.value = true;
    await tester.pump();
    expect(find.text('100'), findsOneWidget);

    target.value = 150;
    await tester.pump();
    expect(find.text('150'), findsOneWidget);

    reduceMotion.value = false;
    await tester.pump();
    target.value = 200;
    await tester.pump();
    expect(find.text('150'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 100));
    expect(_displayedValue(tester), inExclusiveRange(150, 200));

    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('200'), findsOneWidget);
  });
}

int _displayedValue(WidgetTester tester) {
  final text = tester.widget<Text>(find.byType(Text));
  return int.parse(text.data!);
}

class _CounterHarness extends StatelessWidget {
  _CounterHarness({required this.reduceMotion, required this.target});

  final ValueListenable<bool> reduceMotion;
  final ValueListenable<int> target;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: reduceMotion,
      builder: (context, disabled, _) => MediaQuery(
        data: MediaQueryData(disableAnimations: disabled),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: ValueListenableBuilder<int>(
            valueListenable: target,
            builder: (context, value, _) => AnimatedCounter(
              value: value,
              duration: const Duration(milliseconds: 200),
            ),
          ),
        ),
      ),
    );
  }
}
