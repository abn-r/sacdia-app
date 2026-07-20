import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';

void main() {
  testWidgets(
      'both loaders render same-size same-color static dots when reduced', (
    tester,
  ) async {
    final reduceMotion = ValueNotifier<bool>(true);
    addTearDown(reduceMotion.dispose);

    await tester.pumpWidget(
      _LoadingHarness(
        reduceMotion: reduceMotion,
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SacLoading(color: Colors.purple),
            SacLoadingSmall(color: Colors.purple),
          ],
        ),
      ),
    );

    expect(tester.getSize(find.byType(SacLoading)), const Size.square(30));
    expect(tester.getSize(find.byType(SacLoadingSmall)), const Size.square(30));
    expect(find.byType(AnimatedBuilder), findsNothing);

    final dots = tester.widgetList<DecoratedBox>(find.byType(DecoratedBox));
    expect(dots, hasLength(6));
    for (final dot in dots) {
      final decoration = dot.decoration as BoxDecoration;
      expect(decoration.color, Colors.purple);
      expect(decoration.shape, BoxShape.circle);
    }
  });

  testWidgets('runtime toggle replaces moving dots without remounting the app',
      (
    tester,
  ) async {
    final reduceMotion = ValueNotifier<bool>(false);
    addTearDown(reduceMotion.dispose);

    await tester.pumpWidget(
      _LoadingHarness(
        reduceMotion: reduceMotion,
        child: const SacLoading(),
      ),
    );

    expect(find.byType(AnimatedBuilder), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 100));

    reduceMotion.value = true;
    await tester.pump();

    expect(find.byType(AnimatedBuilder), findsNothing);
    expect(find.byType(DecoratedBox), findsNWidgets(3));
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets(
      'runtime toggle replaces small moving dots without remounting the app', (
    tester,
  ) async {
    final reduceMotion = ValueNotifier<bool>(false);
    addTearDown(reduceMotion.dispose);

    await tester.pumpWidget(
      _LoadingHarness(
        reduceMotion: reduceMotion,
        child: const SacLoadingSmall(),
      ),
    );

    expect(find.byType(AnimatedBuilder), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 100));

    reduceMotion.value = true;
    await tester.pump();

    expect(find.byType(AnimatedBuilder), findsNothing);
    expect(find.byType(DecoratedBox), findsNWidgets(3));
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}

class _LoadingHarness extends StatelessWidget {
  const _LoadingHarness({required this.reduceMotion, required this.child});

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
          child: Center(child: child),
        ),
      ),
    );
  }
}
