import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/animations/sac_rolling_number.dart';

Widget _host(int value, {bool reduceMotion = false}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: Scaffold(
          body: Center(
            child: SacRollingNumber(
              value: value,
              prefix: 'Enviar ',
              suffix: ' archivos',
            ),
          ),
        ),
      ),
    );

void main() {
  group('SacRollingNumber', () {
    testWidgets('rests as one plain Text', (tester) async {
      await tester.pumpWidget(_host(2));
      expect(find.text('Enviar 2 archivos'), findsOneWidget);
    });

    testWidgets('shows the new value after rolling', (tester) async {
      await tester.pumpWidget(_host(2));
      await tester.pumpWidget(_host(3));
      await tester.pump(SacMotion.switcher ~/ 2);

      // Mid-roll both numbers are on screen.
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);

      await tester.pump(SacMotion.switcher);
      await tester.pump();
      expect(find.text('Enviar 3 archivos'), findsOneWidget);
      expect(find.text('2'), findsNothing);
    });

    testWidgets(
        'keeps the number moving up when it grows and down when it '
        'shrinks', (tester) async {
      await tester.pumpWidget(_host(2));
      await tester.pumpWidget(_host(3));
      await tester.pump(SacMotion.switcher ~/ 2);
      final up = tester.getTopLeft(find.text('3')).dy;
      final old = tester.getTopLeft(find.text('2')).dy;
      expect(up, greaterThan(old));

      await tester.pump(SacMotion.switcher);
      await tester.pumpWidget(_host(1));
      await tester.pump(SacMotion.switcher ~/ 2);
      expect(
        tester.getTopLeft(find.text('1')).dy,
        lessThan(tester.getTopLeft(find.text('3')).dy),
      );
      await tester.pumpAndSettle();
    });

    testWidgets('reduced motion cross-fades without moving', (tester) async {
      await tester.pumpWidget(_host(2, reduceMotion: true));
      await tester.pumpWidget(_host(3, reduceMotion: true));
      await tester.pump(SacMotion.reducedFade ~/ 2);
      expect(
        tester.getTopLeft(find.text('3')).dy,
        tester.getTopLeft(find.text('2')).dy,
      );
      await tester.pumpAndSettle();
      expect(find.text('Enviar 3 archivos'), findsOneWidget);
    });
  });
}
