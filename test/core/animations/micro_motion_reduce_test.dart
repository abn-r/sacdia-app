import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/widgets/status_progress/status_progress.dart';
import 'package:sacdia_app/features/classes/presentation/widgets/class_progress_line.dart';

Widget _host(Widget child, {required bool reduceMotion}) => MaterialApp(
      theme: AppTheme.lightTheme,
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: Scaffold(body: child),
      ),
    );

const _kindLabels = SacStateKindLabels(
  done: 'Hecho',
  current: 'Actual',
  rejected: 'Devuelto',
  pending: 'Pendiente',
);

const _steps = [
  SacStateStep(kind: SacStateKind.done, title: 'Sin enviar'),
  SacStateStep(kind: SacStateKind.current, title: 'Enviado'),
  SacStateStep(kind: SacStateKind.pending, title: 'Validado'),
];

void main() {
  group('M5 states sheet', () {
    testWidgets('animates rows and the ring with motion, then settles',
        (tester) async {
      await tester.pumpWidget(_host(
        const SacStatesSheet(
          title: 'Estados',
          steps: _steps,
          kindLabels: _kindLabels,
        ),
        reduceMotion: false,
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 10));
      expect(tester.binding.transientCallbackCount, greaterThan(0));

      // Runs once: after its total time nothing is left running.
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pump();
      expect(tester.binding.transientCallbackCount, 0);
      expect(find.text('Enviado'), findsOneWidget);
    });

    testWidgets('reduced motion never starts a ticker', (tester) async {
      await tester.pumpWidget(_host(
        const SacStatesSheet(
          title: 'Estados',
          steps: _steps,
          kindLabels: _kindLabels,
        ),
        reduceMotion: true,
      ));
      await tester.pump();
      expect(tester.binding.transientCallbackCount, 0);
    });
  });

  group('M7 class at 100 %', () {
    testWidgets('reduced motion: no timer, no pulse, no running ticker',
        (tester) async {
      await tester.pumpWidget(_host(
        const ClassProgressLine(percent: 100, progress: 1),
        reduceMotion: true,
      ));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 1500));
      expect(tester.binding.transientCallbackCount, 0);
      expect(find.text('100%'), findsOneWidget);
    });

    testWidgets('with motion it celebrates once after the counter',
        (tester) async {
      await tester.pumpWidget(_host(
        const ClassProgressLine(percent: 100, progress: 1),
        reduceMotion: false,
      ));
      // Counter wait (240) + count (600), then the pulse and sheen run.
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.transientCallbackCount, greaterThan(0));
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pump();
      expect(tester.binding.transientCallbackCount, 0);
    });
  });
}
