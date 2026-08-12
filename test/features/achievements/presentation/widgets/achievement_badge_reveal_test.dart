import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/features/achievements/presentation/widgets/achievement_badge_reveal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpReveal(
    WidgetTester tester, {
    required bool reduceMotion,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: reduceMotion,
          ),
          child: child!,
        ),
        home: const Scaffold(
          body: Center(
            child: AchievementBadgeReveal(
              child: SizedBox(
                key: Key('badge-child'),
                width: 80,
                height: 80,
                child: ColoredBox(color: Colors.purple),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Opacity _opacityOf(WidgetTester tester) {
    return tester.widget<Opacity>(
      find.descendant(
        of: find.byType(AchievementBadgeReveal),
        matching: find.byType(Opacity),
      ),
    );
  }

  Transform _transformOf(WidgetTester tester) {
    return tester.widget<Transform>(
      find.descendant(
        of: find.byType(AchievementBadgeReveal),
        matching: find.byType(Transform),
      ),
    );
  }

  testWidgets('with motion enabled, settles at identity and full opacity',
      (tester) async {
    await pumpReveal(tester, reduceMotion: false);

    expect(_opacityOf(tester).opacity, lessThan(1));

    await tester.pump(SacMotion.badgeReveal);
    await tester.pump(const Duration(milliseconds: 16));

    expect(_opacityOf(tester).opacity, 1);
    final matrix = _transformOf(tester).transform;
    expect(matrix.getTranslation().x, 0);
    expect(matrix.getTranslation().y, 0);
    // rotateY settled → near identity storage for rotation terms.
    expect(matrix.storage[0], closeTo(1, 0.001));
    expect(matrix.storage[10], closeTo(1, 0.001));
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('with reduced motion, appears immediately in final state',
      (tester) async {
    await pumpReveal(tester, reduceMotion: true);
    await tester.pump();

    expect(_opacityOf(tester).opacity, 1);
    final matrix = _transformOf(tester).transform;
    expect(matrix.storage[0], closeTo(1, 0.001));
    expect(matrix.storage[10], closeTo(1, 0.001));
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('disposing leaves no pending frames from the reveal',
      (tester) async {
    await pumpReveal(tester, reduceMotion: false);
    await tester.pump(const Duration(milliseconds: 100));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('does not loop — stays settled after one forward', (tester) async {
    await pumpReveal(tester, reduceMotion: false);
    await tester.pump(SacMotion.badgeReveal);
    await tester.pump(const Duration(milliseconds: 16));
    expect(_opacityOf(tester).opacity, 1);

    await tester.pump(SacMotion.badgeReveal);
    await tester.pump(const Duration(milliseconds: 16));
    expect(_opacityOf(tester).opacity, 1);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}
