import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/class_tone.dart';
import 'package:sacdia_app/core/widgets/sac_progress_ring.dart';
import 'package:sacdia_app/features/dashboard/presentation/widgets/current_class_card.dart';
import '../../../../support/l10n_test_support.dart';
import '../../../../support/riverpod_test_support.dart';

Future<void> _pump(WidgetTester tester, Widget card) async {
  await tester.pumpWidget(
    testProviderScope(
      child: MaterialApp(home: Scaffold(body: Center(child: card))),
    ),
  );
  await tester.pump();
}

void main() {
  setUpAll(loadSpanishTranslations);

  testWidgets('the progress ring and percentage use the class color',
      (tester) async {
    await _pump(
      tester,
      const CurrentClassCard(
          currentClassName: 'Viajero', fallbackProgress: 0.5),
    );

    final ring = tester.widget<SacProgressRing>(find.byType(SacProgressRing));
    expect(ring.color, AppColors.colorViajero);

    final context = tester.element(find.byType(SacProgressRing));
    final tone = ClassTone.of(context, AppColors.colorViajero);
    expect(ring.trackColor, tone.container);
    final percent = tester.widget<Text>(find.text('50%'));
    expect(percent.style?.color, tone.onContainer);
  });

  testWidgets('a completed class keeps the semantic completed badge',
      (tester) async {
    await _pump(
      tester,
      const CurrentClassCard(currentClassName: 'Guía', fallbackProgress: 1),
    );

    expect(find.byType(SacProgressRing), findsNothing);
    expect(find.text('Completada'), findsOneWidget);
  });
}
