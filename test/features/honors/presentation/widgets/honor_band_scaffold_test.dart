import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/honors/presentation/widgets/honor_band_scaffold.dart';
import 'package:sacdia_app/features/honors/presentation/widgets/honor_progress_band.dart';

import '../../../../support/l10n_test_support.dart';

const _band = Color(0xFF9C6A3E);

Future<void> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: HonorBandScaffold(
        bandColor: _band,
        paintColor: _band,
        honorName: 'Perros',
        categoryName: 'Estudio de la Naturaleza',
        metaLabel: 'Validada',
        step: HonorWorkStep.validated,
        progress: 1,
        tabLabels: const ['Resumen', 'Mi trabajo'],
        tabBuilder: (_, __) => const SizedBox(height: 2000),
      ),
    ),
  );
  await tester.pump();
}

Finder _barTitle() => find.descendant(
      of: find.byType(AppBar),
      matching: find.text('Perros'),
    );

void main() {
  setUpAll(loadSpanishTranslations);

  testWidgets('at rest there is no frosted bar and no bar title',
      (tester) async {
    await _pump(tester);

    expect(find.byKey(const ValueKey('honor-frosted-bar')), findsNothing);
    expect(_barTitle(), findsNothing);
  });

  testWidgets('scrolling fades in the frosted bar, then the honor name',
      (tester) async {
    await _pump(tester);

    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -20));
    await tester.pump();
    expect(find.byKey(const ValueKey('honor-frosted-bar')), findsOneWidget);
    expect(_barTitle(), findsNothing);

    await tester.drag(
        find.byType(SingleChildScrollView), const Offset(0, -400));
    await tester.pump();
    expect(_barTitle(), findsOneWidget);
  });

  testWidgets('over the band the bar is white; past it, it takes the page look',
      (tester) async {
    await _pump(tester);
    HonorTopBarTone tone() =>
        tester.widget<HonorTopBarTone>(find.byType(HonorTopBarTone));

    expect(tone().onBand, isTrue);
    expect(tone().foreground, Colors.white);

    await tester.drag(
        find.byType(SingleChildScrollView), const Offset(0, -900));
    await tester.pump();

    expect(tone().onBand, isFalse);
    expect(tone().foreground, isNot(Colors.white));
  });

  testWidgets('pulling past the top shows the band color above the band',
      (tester) async {
    await _pump(tester);

    final bandTop = tester.getTopLeft(find.byType(HonorProgressBand)).dy;
    final fills = find
        .byWidgetPredicate((w) => w is ColoredBox && w.color == _band)
        .evaluate()
        .map((e) => tester.getRect(find.byWidget(e.widget)));

    expect(
      fills.any((r) => r.bottom == bandTop && r.height >= 800),
      isTrue,
    );
  });
}
