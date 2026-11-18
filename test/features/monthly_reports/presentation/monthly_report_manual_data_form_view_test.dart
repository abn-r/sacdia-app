import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/providers/riverpod_aliases.dart';
import 'package:sacdia_app/features/materials/presentation/widgets/qty_stepper.dart';
import 'package:sacdia_app/features/monthly_reports/domain/entities/monthly_report.dart';
import 'package:sacdia_app/features/monthly_reports/presentation/providers/monthly_reports_providers.dart';
import 'package:sacdia_app/features/monthly_reports/presentation/views/monthly_report_manual_data_form_view.dart';

import '../support/monthly_reports_harness.dart';

const _report = MonthlyReport(
  id: 'report-1',
  enrollmentId: 'enrollment-1',
  month: 11,
  year: 2026,
  status: 'draft',
  manualData: MonthlyReportManualData(bibleStudiesReceiving: 3),
);

List<Override> _overrides(
  FakeMonthlyReportsRepository repository, {
  MonthlyReportManualData? previous,
}) =>
    [
      monthlyReportsRepositoryProvider.overrideWithValue(repository),
      monthlyReportPreviousManualDataProvider
          .overrideWith((ref, key) async => previous),
    ];

/// Opens the form the way the detail does: as a sheet over a page.
Future<void> _openSheet(
  WidgetTester tester,
  FakeMonthlyReportsRepository repository, {
  MonthlyReportManualSection section = MonthlyReportManualSection.mission,
  MonthlyReportManualData? previous,
}) async {
  await pumpMonthlyReportsApp(
    tester,
    overrides: _overrides(repository, previous: previous),
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () => MonthlyReportManualDataFormView.show(
              context,
              _report,
              section: section,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

Finder _plusOf(String field) => find
    .descendant(
      of: find.byKey(ValueKey('monthly-report-field-$field')),
      matching: find.byType(GestureDetector),
    )
    .last;

Finder _minusOf(String field) => find
    .descendant(
      of: find.byKey(ValueKey('monthly-report-field-$field')),
      matching: find.byType(GestureDetector),
    )
    .first;

void main() {
  setUpAll(setUpMonthlyReportsLocalization);

  testWidgets('small counts are steppers and yes/no are switches, no keyboard',
      (tester) async {
    await _openSheet(tester, FakeMonthlyReportsRepository());

    expect(find.text('Actividad misionera'), findsOneWidget);
    expect(find.byType(QtyStepper), findsNWidgets(5));
    expect(find.byType(Switch), findsNWidgets(3));
    expect(find.byType(TextField), findsNothing);
    // The old intro card, per-field chart icon and "Sin cambios" are gone.
    expect(find.text('Sin cambios'), findsNothing);
    expect(find.textContaining('Completa solo lo que pasó'), findsNothing);
    expect(find.text('Se guarda solo'), findsOneWidget);
    expect(find.text('Listo'), findsOneWidget);
  });

  testWidgets('autosaves after a pause, debounced, and says so',
      (tester) async {
    final repository = FakeMonthlyReportsRepository();
    await _openSheet(tester, repository);

    // Existing value comes from the report.
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('monthly-report-field-studies')),
        matching: find.text('3'),
      ),
      findsOneWidget,
    );

    await tester.tap(_plusOf('studies'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(_plusOf('studies'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Guardando…'), findsOneWidget);
    expect(repository.saved, isEmpty, reason: 'still inside the debounce');

    await tester.pump(kMonthlyReportAutosaveDelay);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(repository.saved, hasLength(1), reason: 'two taps, one save');
    expect(repository.saved.single.bibleStudiesReceiving, 5);
    expect(find.text('Guardado hace un momento'), findsOneWidget);
  });

  testWidgets('a switch saves its new value', (tester) async {
    final repository = FakeMonthlyReportsRepository();
    await _openSheet(tester, repository);

    await tester.tap(find.byType(Switch).first);
    await tester.pump(kMonthlyReportAutosaveDelay);
    await tester.pump();

    expect(repository.saved.single.hasWeeklyBibleInstruction, isTrue);
  });

  testWidgets('shows last month as a gray hint next to each stepper',
      (tester) async {
    await _openSheet(
      tester,
      FakeMonthlyReportsRepository(),
      previous: const MonthlyReportManualData(bibleStudiesReceiving: 4),
    );

    expect(find.text('oct: 4'), findsOneWidget);
  });

  testWidgets('without last month there is no hint', (tester) async {
    await _openSheet(tester, FakeMonthlyReportsRepository());

    expect(find.textContaining('oct:'), findsNothing);
  });

  testWidgets('a failed save shows the error with retry, and retry saves',
      (tester) async {
    final repository = FakeMonthlyReportsRepository(saveResults: [false, true]);
    await _openSheet(tester, repository);

    await tester.tap(_plusOf('soulTarget'));
    await tester.pump(kMonthlyReportAutosaveDelay);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('No se pudo guardar'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);

    await tester.tap(find.text('Reintentar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(repository.saved, hasLength(2));
    expect(repository.saved.last.soulTarget, 1);
    expect(find.text('Guardado hace un momento'), findsOneWidget);
  });

  testWidgets('"Listo" saves what is pending and closes the sheet',
      (tester) async {
    final repository = FakeMonthlyReportsRepository();
    await _openSheet(tester, repository);

    await tester.tap(_plusOf('unbaptized'));
    await tester.pump();
    // No waiting for the debounce: Listo flushes it.
    await tester.tap(find.byKey(const Key('monthly-report-form-done')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(repository.saved, hasLength(1));
    expect(repository.saved.single.unbaptizedMembers, 1);
    expect(find.byType(MonthlyReportManualDataFormView), findsNothing);
  });

  testWidgets('a stepper does not go below zero', (tester) async {
    final repository = FakeMonthlyReportsRepository();
    await _openSheet(tester, repository);

    await tester.tap(_minusOf('soulTarget'));
    await tester.pump(kMonthlyReportAutosaveDelay);
    await tester.pump();

    expect(repository.saved, isEmpty);
  });

  testWidgets('the services section keeps its two text fields', (tester) async {
    await _openSheet(
      tester,
      FakeMonthlyReportsRepository(),
      section: MonthlyReportManualSection.service,
    );

    expect(find.text('Servicio a la comunidad'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.byType(QtyStepper), findsNothing);
  });
}
