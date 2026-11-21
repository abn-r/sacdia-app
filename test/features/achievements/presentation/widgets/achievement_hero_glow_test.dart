import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/achievements/presentation/widgets/achievement_hero_glow.dart';
import 'package:sacdia_app/features/achievements/presentation/widgets/achievement_shine.dart';

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  bool reduceMotion = false,
}) {
  return tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: child),
      ),
    ),
  );
}

const _badge = SizedBox.square(dimension: 100);

Finder get _band => find.byType(ShaderMask);

void main() {
  group('AchievementHeroGlow', () {
    testWidgets('reserves room for the halo and shines every 5 seconds',
        (tester) async {
      await _pump(
        tester,
        const AchievementHeroGlow(
          color: Colors.orange,
          size: 100,
          child: _badge,
        ),
        reduceMotion: true,
      );

      expect(
        tester.getSize(find.byType(AchievementHeroGlow)),
        const Size.square(100 * AchievementHeroGlow.extent),
      );
      expect(
        tester.widget<AchievementShine>(find.byType(AchievementShine)).period,
        const Duration(seconds: 5),
      );
    });
  });

  group('AchievementShine', () {
    testWidgets(
        'a pass of light crosses the badge, then it rests until the '
        'next one', (tester) async {
      await _pump(
        tester,
        const AchievementShine(period: Duration(seconds: 10), child: _badge),
      );

      // The first pass waits a beat after the screen opens.
      expect(_band, findsNothing);
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pump(const Duration(milliseconds: 500));
      expect(_band, findsOneWidget);

      // Once the pass is over the badge rests: nothing animates.
      await tester.pump(AchievementShine.sweep);
      expect(_band, findsNothing);
      expect(tester.hasRunningAnimations, isFalse);

      // Still resting just before the next period.
      await tester.pump(const Duration(seconds: 8));
      expect(_band, findsNothing);

      // And the next pass comes one period after the first.
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pump(const Duration(milliseconds: 300));
      expect(_band, findsOneWidget);
    });

    testWidgets('with reduced motion the light never passes', (tester) async {
      await _pump(
        tester,
        const AchievementShine(period: Duration(seconds: 10), child: _badge),
        reduceMotion: true,
      );

      await tester.pump(const Duration(seconds: 25));
      expect(_band, findsNothing);
      expect(tester.hasRunningAnimations, isFalse);
    });
  });
}
