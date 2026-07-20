import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';

void main() {
  testWidgets('renders animated card immediately when motion is reduced', (
    tester,
  ) async {
    final reduceMotion = ValueNotifier<bool>(true);
    addTearDown(reduceMotion.dispose);

    await tester.pumpWidget(
      _MotionHarness(
        reduceMotion: reduceMotion,
        child: const SacCard(
          animate: true,
          animationDelay: Duration(seconds: 1),
          child: Text('card'),
        ),
      ),
    );

    expect(find.text('card'), findsOneWidget);
    expect(_cardTransition(FadeTransition), findsNothing);
    expect(_cardTransition(ScaleTransition), findsNothing);
  });

  testWidgets('runtime toggle cancels a pending card entrance', (tester) async {
    final reduceMotion = ValueNotifier<bool>(false);
    addTearDown(reduceMotion.dispose);

    await tester.pumpWidget(
      _MotionHarness(
        reduceMotion: reduceMotion,
        child: const SacCard(
          animate: true,
          animationDelay: Duration(milliseconds: 500),
          child: Text('card'),
        ),
      ),
    );

    expect(_fade(tester).opacity.value, 0);
    expect(_scale(tester).scale.value, lessThan(1));

    reduceMotion.value = true;
    await tester.pump();
    expect(_cardTransition(FadeTransition), findsNothing);
    expect(_cardTransition(ScaleTransition), findsNothing);

    await tester.pump(const Duration(milliseconds: 600));
    reduceMotion.value = false;
    await tester.pump();

    expect(_fade(tester).opacity.value, 1);
    expect(_scale(tester).scale.value, 1);
  });
}

FadeTransition _fade(WidgetTester tester) =>
    tester.widget<FadeTransition>(_cardTransition(FadeTransition));

ScaleTransition _scale(WidgetTester tester) =>
    tester.widget<ScaleTransition>(_cardTransition(ScaleTransition));

Finder _cardTransition(Type type) => find.descendant(
      of: find.byType(SacCard),
      matching: find.byType(type),
    );

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
        child: MaterialApp(home: Scaffold(body: child)),
      ),
    );
  }
}
