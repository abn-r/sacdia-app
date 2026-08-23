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

    testWidgets('should stay at scale 1 when motion is reduced', (tester) async {
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
