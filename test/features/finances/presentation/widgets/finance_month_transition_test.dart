import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/finances/presentation/widgets/balance_header_card.dart'
    show kFinanceStaleOpacity;
import 'package:sacdia_app/features/finances/presentation/widgets/finance_month_transition.dart';

Widget _host({
  required String monthKey,
  required int direction,
  bool isStale = false,
  bool reduceMotion = false,
}) {
  return MaterialApp(
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
      child: child!,
    ),
    home: FinanceMonthTransition(
      monthKey: monthKey,
      direction: direction,
      isStale: isStale,
      child: const SizedBox(key: Key('content'), width: 200, height: 100),
    ),
  );
}

double _opacity(WidgetTester tester) => tester
    .widget<AnimatedOpacity>(
      find.descendant(
        of: find.byType(FinanceMonthTransition),
        matching: find.byType(AnimatedOpacity),
      ),
    )
    .opacity;

SlideTransition _slide(WidgetTester tester) => tester.widget<SlideTransition>(
      find.descendant(
        of: find.byType(FinanceMonthTransition),
        matching: find.byType(SlideTransition),
      ),
    );

void main() {
  testWidgets('does not animate the first month', (tester) async {
    await tester.pumpWidget(_host(monthKey: '2026-04', direction: 1));

    expect(_slide(tester).position.value, Offset.zero);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('dims while stale and clears the dim when it settles',
      (tester) async {
    await tester.pumpWidget(
      _host(monthKey: '2026-04', direction: 1, isStale: true),
    );
    await tester.pumpAndSettle();
    expect(_opacity(tester), kFinanceStaleOpacity);

    await tester.pumpWidget(_host(monthKey: '2026-04', direction: 1));
    await tester.pumpAndSettle();
    expect(_opacity(tester), 1);
  });

  testWidgets('a later month slides in from the right', (tester) async {
    await tester.pumpWidget(_host(monthKey: '2026-04', direction: 1));
    await tester.pumpWidget(_host(monthKey: '2026-05', direction: 1));
    await tester.pump();

    expect(_slide(tester).position.value.dx, greaterThan(0));

    await tester.pump(FinanceMonthTransition.slideDuration);
    expect(_slide(tester).position.value, Offset.zero);
  });

  testWidgets('an earlier month slides in from the left', (tester) async {
    await tester.pumpWidget(_host(monthKey: '2026-04', direction: -1));
    await tester.pumpWidget(_host(monthKey: '2026-03', direction: -1));
    await tester.pump();

    expect(_slide(tester).position.value.dx, lessThan(0));

    await tester.pumpAndSettle();
    expect(_slide(tester).position.value, Offset.zero);
  });

  testWidgets('the slide takes about a quarter of a second', (tester) async {
    expect(
      FinanceMonthTransition.slideDuration.inMilliseconds,
      inInclusiveRange(220, 280),
    );
  });

  testWidgets('with reduced motion there is no slide, only a fade',
      (tester) async {
    await tester.pumpWidget(
      _host(monthKey: '2026-04', direction: 1, reduceMotion: true),
    );
    await tester.pumpWidget(
      _host(
          monthKey: '2026-05', direction: 1, isStale: true, reduceMotion: true),
    );
    await tester.pump();

    expect(
      find.descendant(
        of: find.byType(FinanceMonthTransition),
        matching: find.byType(SlideTransition),
      ),
      findsNothing,
    );

    await tester.pumpAndSettle();
    expect(_opacity(tester), kFinanceStaleOpacity);
  });
}
