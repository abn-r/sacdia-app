import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/widgets/sac_badge.dart';
import 'package:sacdia_app/features/honors/presentation/widgets/honor_progress_band.dart';

import '../../../../support/l10n_test_support.dart';

void main() {
  setUpAll(loadSpanishTranslations);

  Future<void> pumpBand(
    WidgetTester tester, {
    double? progress,
    HonorWorkStep? step,
    Widget? badge,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HonorProgressBand(
            bandColor: const Color(0xFF1B5E20),
            honorName: 'Arte de acampar',
            categoryName: 'Naturaleza',
            progress: progress,
            badge: badge,
            metaLabel: 'Básico · General',
            step: step,
            topInset: 0,
          ),
        ),
      ),
    );
  }

  double fillOf(WidgetTester tester, int index) => tester
      .widget<FractionallySizedBox>(find.descendant(
        of: find.byKey(ValueKey('honor-step-segment-$index')),
        matching: find.byType(FractionallySizedBox),
      ))
      .widthFactor!;

  testWidgets('the patch never gets a ring', (tester) async {
    await pumpBand(tester, progress: 0.4, step: HonorWorkStep.working);
    await tester.pump(const Duration(seconds: 1));

    expect(
      find.descendant(
        of: find.byType(HonorProgressBand),
        matching: find.byType(CustomPaint),
      ),
      findsNothing,
    );
  });

  testWidgets('without a progress there is no percent semantics',
      (tester) async {
    final handle = tester.ensureSemantics();
    await pumpBand(tester);

    expect(find.text('Básico · General'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('% completado')), findsNothing);
    handle.dispose();
  });

  testWidgets('while working, the progress fills only the working step',
      (tester) async {
    final handle = tester.ensureSemantics();
    await pumpBand(tester, progress: 0.4, step: HonorWorkStep.working);
    await tester.pump(const Duration(seconds: 1));

    expect(fillOf(tester, 0), 1);
    expect(fillOf(tester, 1), closeTo(0.4, 0.001));
    expect(fillOf(tester, 2), 0);
    expect(fillOf(tester, 3), 0);
    expect(find.bySemanticsLabel('40% completado'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('past the working step the progress does not cut any segment',
      (tester) async {
    await pumpBand(tester, progress: 0.4, step: HonorWorkStep.inReview);
    await tester.pump(const Duration(seconds: 1));

    expect(fillOf(tester, 1), 1);
    expect(fillOf(tester, 2), 1);
    expect(fillOf(tester, 3), 0);
  });

  testWidgets('no step reached says the honor is not enrolled yet',
      (tester) async {
    final handle = tester.ensureSemantics();
    await pumpBand(tester);

    expect(find.bySemanticsLabel('Aún no inscrita'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('the path announces the current step', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpBand(tester, step: HonorWorkStep.validated);

    expect(find.bySemanticsLabel('Etapa 4 de 4: Validada'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('shows the status badge before the meta line', (tester) async {
    await pumpBand(
      tester,
      badge: const SacBadge.success(label: 'Validada'),
    );

    expect(find.byType(SacBadge), findsOneWidget);
    expect(
      tester.getTopLeft(find.byType(SacBadge)).dx,
      lessThan(tester.getTopLeft(find.text('Básico · General')).dx),
    );
  });
}
