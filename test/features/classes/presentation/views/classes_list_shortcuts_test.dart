import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/classes/domain/entities/progressive_class.dart';
import 'package:sacdia_app/features/classes/presentation/providers/classes_providers.dart';
import 'package:sacdia_app/features/classes/presentation/views/classes_list_view.dart';
import '../../../../support/l10n_test_support.dart';
import '../../../../support/riverpod_test_support.dart';

Future<void> _pump(WidgetTester tester, List<ProgressiveClass> classes) async {
  await tester.pumpWidget(
    testProviderScope(
      overrides: [
        userClassesProvider.overrideWith((ref) async => classes),
      ],
      child: const MaterialApp(
        home: Scaffold(body: ClassesListViewBody()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadSpanishTranslations);

  testWidgets('the old roadmap entry is gone', (tester) async {
    await _pump(tester, const [
      ProgressiveClass(
          id: 12,
          name: 'Guía',
          clubTypeId: 2,
          investitureStatus: 'IN_PROGRESS'),
    ]);

    expect(find.text('Ver mi camino completo'), findsNothing);
    expect(find.text('Clases por club'), findsOneWidget);
    expect(find.text('Certificaciones'), findsNothing);
  });

  testWidgets('an invested Master Guide sees both shortcuts in one row',
      (tester) async {
    await _pump(tester, const [
      ProgressiveClass(
        id: 13,
        name: 'Guía Mayor',
        clubTypeId: ProgressiveClass.masterGuidesClubTypeId,
        investitureStatus: 'INVESTIDO',
      ),
    ]);

    final catalog = tester.getRect(find.text('Clases por club'));
    final certifications = tester.getRect(find.text('Certificaciones'));
    expect(catalog.top, certifications.top);
    expect(catalog.left, lessThan(certifications.left));
  });
}
