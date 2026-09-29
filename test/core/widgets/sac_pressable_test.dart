import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';

void main() {
  group('SacPressable', () {
    testWidgets('should scale to pressScale on pointer down', (tester) async {
      await tester.pumpWidget(
        _MotionHarness(
          reduceMotion: false,
          child: SacPressable(
            onTap: () {},
            child: const Text('press'),
          ),
        ),
      );

      final gesture = await tester.press(find.text('press'));
      await tester.pump();

      expect(
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
        SacMotion.pressScale,
      );

      await gesture.up();
    });

    testWidgets('should stay at scale 1 when motion is reduced',
        (tester) async {
      await tester.pumpWidget(
        _MotionHarness(
          reduceMotion: true,
          child: SacPressable(
            onTap: () {},
            child: const Text('press'),
          ),
        ),
      );

      await tester.press(find.text('press'));
      await tester.pump();

      expect(
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
        1,
      );
    });

    testWidgets('listenOnly releases the scale once the pointer drags',
        (tester) async {
      await tester.pumpWidget(
        _MotionHarness(
          reduceMotion: false,
          child: const SacPressable(
            listenOnly: true,
            child: Text('press'),
          ),
        ),
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('press')),
      );
      await tester.pump();

      expect(
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
        SacMotion.pressScale,
      );

      await gesture.moveBy(const Offset(0, 40));
      await tester.pump();

      expect(
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
        1,
      );

      await gesture.up();
    });

    testWidgets('SacInkWell scales and ignores splash arguments',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _MotionHarness(
          reduceMotion: false,
          child: SacInkWell(
            onTap: () => taps++,
            splashColor: const Color(0xFFFF0000),
            highlightColor: const Color(0xFF00FF00),
            borderRadius: BorderRadius.circular(12),
            child: const Text('row'),
          ),
        ),
      );

      final gesture = await tester.press(find.text('row'));
      await tester.pump();

      expect(
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
        SacMotion.pressScale,
      );
      expect(find.byType(InkWell), findsNothing);

      await gesture.up();
      await tester.pump();
      expect(taps, 1);
    });
  });
}

class _MotionHarness extends StatelessWidget {
  const _MotionHarness({required this.reduceMotion, required this.child});

  final bool reduceMotion;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: MaterialApp(home: Scaffold(body: child)),
    );
  }
}
