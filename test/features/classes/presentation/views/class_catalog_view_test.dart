import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/classes/presentation/catalog/class_catalog.dart';
import 'package:sacdia_app/features/classes/presentation/catalog/class_catalog_providers.dart';
import 'package:sacdia_app/features/classes/presentation/views/class_catalog_view.dart';
import '../../../../support/l10n_test_support.dart';
import '../../../../support/riverpod_test_support.dart';

const _sections = [
  ClassCatalogSection(clubTypeId: 1, entries: [
    ClassCatalogEntry(
      classId: 1,
      name: 'Corderitos',
      clubTypeId: 1,
      minAge: 6,
      maxAge: 6,
      status: ClassCatalogStatus.invested,
      year: '2004',
    ),
    ClassCatalogEntry(
      classId: 3,
      name: 'Abejitas Industriosas',
      clubTypeId: 1,
      minAge: 7,
      maxAge: 9,
      status: ClassCatalogStatus.notInvested,
    ),
  ]),
  ClassCatalogSection(clubTypeId: 2, entries: [
    ClassCatalogEntry(
      classId: 12,
      name: 'Guía',
      clubTypeId: 2,
      minAge: 15,
      maxAge: 15,
      status: ClassCatalogStatus.inProgress,
      year: '2026',
      isCurrent: true,
    ),
  ]),
  ClassCatalogSection(clubTypeId: 3, entries: [
    ClassCatalogEntry(
      classId: 13,
      name: 'Guía Mayor',
      clubTypeId: 3,
      minAge: 16,
      status: ClassCatalogStatus.expired,
      year: '2025',
    ),
  ]),
];

Future<void> _pump(WidgetTester tester, {bool reduceMotion = false}) async {
  await tester.pumpWidget(
    testProviderScope(
      overrides: [
        classCatalogProvider.overrideWith((ref) async => _sections),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduceMotion),
          child: const ClassCatalogView(),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUpAll(loadSpanishTranslations);

  testWidgets('lists every club with ages, counts and statuses',
      (tester) async {
    await _pump(tester);
    await tester.pumpAndSettle();

    expect(find.text('Aventureros'), findsOneWidget);
    expect(find.text('6 a 9 años · 2 clases'), findsOneWidget);
    expect(find.text('Conquistadores'), findsOneWidget);
    expect(find.text('15 años · 1 clase'), findsOneWidget);
    expect(find.text('Guías Mayores'), findsOneWidget);
    expect(find.text('Desde 16 años · 1 clase'), findsOneWidget);

    expect(find.text('Investido · 2004'), findsOneWidget);
    expect(find.text('Sin investir'), findsOneWidget);
    expect(find.text('Cursando · 2026'), findsOneWidget);
    expect(find.text('Vencida · 2025'), findsOneWidget);
    expect(find.text('7 a 9 años'), findsOneWidget);
  });

  testWidgets('the current class is labelled and highlighted once',
      (tester) async {
    await _pump(tester);

    expect(find.text('Tu clase actual'), findsOneWidget);
    // The highlight runs after the scroll and then stops for good.
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('rows are read-only', (tester) async {
    await _pump(tester, reduceMotion: true);
    await tester.pumpAndSettle();

    expect(find.byType(InkWell), findsNothing);
    expect(find.byType(GestureDetector).hitTestable(), findsNothing);
  });
}
