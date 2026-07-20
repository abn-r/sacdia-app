import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/animations/staggered_list_animation.dart';

void main() {
  testWidgets('direct item is immediately stable when motion is reduced', (
    tester,
  ) async {
    final reduceMotion = ValueNotifier<bool>(true);
    addTearDown(reduceMotion.dispose);

    await tester.pumpWidget(
      _MotionHarness(
        reduceMotion: reduceMotion,
        child: const StaggeredListItem(
          index: 4,
          initialDelay: Duration(seconds: 1),
          child: Text('item'),
        ),
      ),
    );

    expect(find.text('item'), findsOneWidget);
    expect(find.byType(FadeTransition), findsNothing);
    expect(find.byType(SlideTransition), findsNothing);
  });

  testWidgets('direct item cancels delayed movement after runtime toggle', (
    tester,
  ) async {
    final reduceMotion = ValueNotifier<bool>(false);
    addTearDown(reduceMotion.dispose);

    await tester.pumpWidget(
      _MotionHarness(
        reduceMotion: reduceMotion,
        child: const StaggeredListItem(
          index: 0,
          initialDelay: Duration(milliseconds: 500),
          child: Text('item'),
        ),
      ),
    );

    expect(find.byType(FadeTransition), findsOneWidget);
    expect(_fade(tester).opacity.value, 0);

    reduceMotion.value = true;
    await tester.pump();

    expect(find.byType(FadeTransition), findsNothing);
    expect(find.byType(SlideTransition), findsNothing);

    await tester.pump(const Duration(milliseconds: 600));
    reduceMotion.value = false;
    await tester.pump();

    expect(_fade(tester).opacity.value, 1);
    expect(_slide(tester).position.value, Offset.zero);
  });
}

FadeTransition _fade(WidgetTester tester) =>
    tester.widget<FadeTransition>(find.byType(FadeTransition));

SlideTransition _slide(WidgetTester tester) =>
    tester.widget<SlideTransition>(find.byType(SlideTransition));

class _MotionHarness extends StatelessWidget {
  const _MotionHarness({required this.reduceMotion, required this.child});

  final ValueListenable<bool> reduceMotion;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: reduceMotion,
      builder: (context, disabled, _) => MediaQuery(
        data: MediaQueryData(disableAnimations: disabled),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: child,
        ),
      ),
    );
  }
}
