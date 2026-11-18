import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/providers/riverpod_aliases.dart';
import 'package:sacdia_app/features/monthly_reports/domain/entities/monthly_report.dart';
import 'package:sacdia_app/features/monthly_reports/presentation/providers/monthly_reports_providers.dart';
import 'package:sacdia_app/features/monthly_reports/presentation/views/monthly_report_detail_view.dart';

import '../support/monthly_reports_harness.dart';

MonthlyReport _report({
  required String status,
  int month = 10,
  int year = 2026,
  MonthlyReportManualData? manual,
  MonthlySnapshotOverride? snapshot,
  String? reviewComment,
}) =>
    MonthlyReport(
      id: 'report-1',
      enrollmentId: 'enrollment-1',
      month: month,
      year: year,
      status: status,
      manualData: manual,
      snapshot: snapshot?.value,
      generatedAt: DateTime(2026, 11, 5),
      submittedAt: DateTime(2026, 11, 6),
      reviewComment: reviewComment,
    );

class MonthlySnapshotOverride {
  const MonthlySnapshotOverride(this.value);
  final MonthlyReportSnapshot value;
}

const _snapshot = MonthlySnapshotOverride(
  MonthlyReportSnapshot(
    memberCount: 24,
    activities: MonthlyReportActivitiesSummary(total: 5),
    finances: MonthlyReportFinancesSummary(
      income: 3240,
      expenses: 1180,
      balance: 2060,
    ),
  ),
);

// Reuniones y Certificados llenas; Misión y Servicio vacías.
const _twoMissing = MonthlyReportManualData(
  planningMeetings: 2,
  certificatesDelivered: true,
);

List<Override> _overrides(MonthlyReport report) => [
      monthlyReportDetailProvider(report.id)
          .overrideWith((ref) async => report),
      monthlyReportDueDayProvider.overrideWithValue(5),
      monthlyReportPreviewProvider.overrideWith(
        (ref, params) async => MonthlyReportPreview(
          enrollmentId: params.enrollmentId,
          month: params.month,
          year: params.year,
          totalActivities: 5,
          totalAttendance: 0,
          totalMembers: 24,
          attendanceRate: 0,
          snapshot: _snapshot.value,
        ),
      ),
      monthlyReportPreviousManualDataProvider
          .overrideWith((ref, key) async => null),
    ];

void main() {
  setUpAll(setUpMonthlyReportsLocalization);

  Future<void> pumpDetail(WidgetTester tester, MonthlyReport report) =>
      pumpMonthlyReportsApp(
        tester,
        home: MonthlyReportDetailView(reportId: report.id),
        overrides: _overrides(report),
      );

  testWidgets('draft: state panel, what you fill in and what fills itself',
      (tester) async {
    final report = _report(status: 'draft', month: 11, manual: _twoMissing);
    await pumpDetail(tester, report);

    expect(find.text('Noviembre 2026'), findsOneWidget);
    // Panel with only the current state, the generation day and the step.
    expect(find.byKey(const Key('monthly-report-state-panel')), findsOneWidget);
    expect(find.text('Borrador'), findsOneWidget);
    expect(
      find.text('Se genera solo el 5 dic con lo que tengas.'),
      findsOneWidget,
    );
    expect(find.text('Paso 1 de 4'), findsOneWidget);

    // Lo llenas tú: 2 of 4 pending.
    expect(find.text('LO LLENAS TÚ'), findsOneWidget);
    expect(find.text('faltan 2'), findsOneWidget);
    expect(find.text('Listo'), findsNWidgets(2));
    expect(find.text('Falta llenar'), findsNWidgets(2));
    expect(find.text('Reuniones'), findsOneWidget);
    expect(find.text('Actividad misionera'), findsOneWidget);
    expect(find.text('Servicio a la comunidad'), findsOneWidget);
    expect(find.text('Certificados'), findsOneWidget);

    // Se llena solo, with the live figures.
    expect(find.text('SE LLENA SOLO'), findsOneWidget);
    expect(find.text('24'), findsOneWidget);

    // One fixed primary action.
    expect(find.text('Llenar lo que falta'), findsOneWidget);
    expect(find.text('Enviar al campo local'), findsNothing);
    expect(find.text('Ver PDF'), findsNothing);
  });

  testWidgets('tapping the panel opens the sheet with the four states',
      (tester) async {
    await pumpDetail(
      tester,
      _report(status: 'draft', month: 11, manual: _twoMissing),
    );

    await tester.tap(find.byKey(const Key('monthly-report-state-panel')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Estados del informe'), findsOneWidget);
    final steps = find.byKey(const ValueKey('states-sheet-steps'));
    for (final name in ['Borrador', 'Generado', 'En revisión', 'Aprobado']) {
      expect(
        find.descendant(of: steps, matching: find.text(name)),
        findsOneWidget,
        reason: name,
      );
    }
    // Future states are described, the current one is not "done".
    expect(find.text('Se genera solo el 5 dic'), findsOneWidget);
  });

  testWidgets('"Llenar lo que falta" opens the first pending section',
      (tester) async {
    await pumpDetail(
      tester,
      _report(status: 'draft', month: 11, manual: _twoMissing),
    );

    await tester.tap(find.text('Llenar lo que falta'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Misión is the first section without data: its fields are on screen.
    expect(
      find.byKey(const ValueKey('monthly-report-field-soulTarget')),
      findsOneWidget,
    );
    expect(find.text('Se guarda solo'), findsOneWidget);
  });

  testWidgets('generated: one 2x2 box of figures and a single send action',
      (tester) async {
    await pumpDetail(
      tester,
      _report(status: 'generated', manual: _twoMissing, snapshot: _snapshot),
    );

    expect(find.text('Generado: falta enviar'), findsOneWidget);
    expect(find.text('Paso 2 de 4'), findsOneWidget);

    final box = find.byKey(const Key('monthly-report-figures'));
    expect(box, findsOneWidget);
    for (final label in [
      'Miembros',
      'Actividades',
      'Ingresos del mes',
      'Saldo del mes'
    ]) {
      expect(
        find.descendant(of: box, matching: find.text(label)),
        findsOneWidget,
        reason: label,
      );
    }
    expect(find.descendant(of: box, matching: find.text('24')), findsOneWidget);
    expect(
      find.descendant(of: box, matching: find.text(r'$3,240.00')),
      findsOneWidget,
    );

    // Sections are label/value groups, not expandable cards.
    expect(find.text('ACTIVIDAD MISIONERA'), findsOneWidget);
    expect(find.text('LO LLENAS TÚ'), findsNothing);

    expect(find.text('Enviar al campo local'), findsOneWidget);
    expect(find.text('Llenar lo que falta'), findsNothing);
  });

  testWidgets('generated: missing numbers are gray text, not a dash',
      (tester) async {
    await pumpDetail(tester, _report(status: 'generated'));

    expect(find.text('—'), findsNothing);
    expect(find.text('Sin dato'), findsWidgets);
  });

  testWidgets('in review: shows the PDF as the only action', (tester) async {
    await pumpDetail(
      tester,
      _report(status: 'submitted', snapshot: _snapshot),
    );

    expect(find.text('En revisión'), findsWidgets);
    expect(find.text('Paso 3 de 4'), findsOneWidget);
    expect(find.text('Ver PDF'), findsOneWidget);
    expect(find.text('Enviar al campo local'), findsNothing);
  });

  testWidgets('rejected: error panel, quoted comment and fix action',
      (tester) async {
    await pumpDetail(
      tester,
      _report(
        status: 'rejected',
        manual: _twoMissing,
        reviewComment: 'Falta la actividad misionera.',
      ),
    );

    expect(find.text('Rechazado'), findsOneWidget);
    expect(
      find.text('Corrige lo que pide el campo local y vuelve a enviarlo.'),
      findsOneWidget,
    );
    expect(find.text('Paso 3 de 4'), findsOneWidget);
    expect(find.text('COMENTARIO DEL CAMPO LOCAL'), findsOneWidget);
    expect(find.text('«Falta la actividad misionera.»'), findsOneWidget);
    expect(find.text('Corregir y reenviar'), findsOneWidget);
    expect(find.text('Enviar al campo local'), findsNothing);
  });

  testWidgets('rejected without a comment shows no quote card', (tester) async {
    await pumpDetail(tester, _report(status: 'rejected'));

    expect(find.text('COMENTARIO DEL CAMPO LOCAL'), findsNothing);
    expect(find.text('Corregir y reenviar'), findsOneWidget);
  });
}
