import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/providers/riverpod_aliases.dart';
import 'package:sacdia_app/features/enrollment/domain/entities/enrollment.dart';
import 'package:sacdia_app/features/enrollment/presentation/providers/enrollment_providers.dart';
import 'package:sacdia_app/features/members/presentation/providers/members_providers.dart';
import 'package:sacdia_app/features/monthly_reports/domain/entities/monthly_report.dart';
import 'package:sacdia_app/features/monthly_reports/presentation/providers/monthly_reports_providers.dart';
import 'package:sacdia_app/features/monthly_reports/presentation/views/monthly_reports_visible_list_view.dart';
import 'package:sacdia_app/features/monthly_reports/presentation/widgets/monthly_report_history.dart';
import 'package:sacdia_app/features/monthly_reports/presentation/widgets/monthly_report_status_chip.dart';

import '../support/monthly_reports_harness.dart';

const _clubContext = ClubContext(clubId: 1, sectionId: 1, roleName: 'director');

const _enrollment = Enrollment(
  id: 1,
  userId: 'user-1',
  clubSectionId: 1,
  year: 2026,
  meetingDays: [],
  status: EnrollmentStatus.active,
);

List<Override> _overrides(List<VisibleMonthlyReport> reports,
        {ClubContext? club = _clubContext}) =>
    [
      clubContextProvider.overrideWith((ref) async => club),
      currentEnrollmentProvider.overrideWith((ref) async => _enrollment),
      monthlyReportsHistoryProvider.overrideWith((ref) async => reports),
    ];

void main() {
  setUpAll(setUpMonthlyReportsLocalization);

  final now = DateTime.now();

  VisibleMonthlyReport report(
    String id,
    int month,
    int year,
    String status, {
    DateTime? submittedAt,
    int? pendingSections,
  }) =>
      VisibleMonthlyReport(
        id: id,
        enrollmentId: 'enrollment-1',
        month: month,
        year: year,
        status: status,
        submittedAt: submittedAt,
        pendingSections: pendingSections,
      );

  testWidgets(
    'groups the current draft under "Por atender" and the rest by year',
    (tester) async {
      await pumpMonthlyReportsApp(
        tester,
        // A narrow phone: nothing may overflow.
        size: const Size(320, 700),
        home: const MonthlyReportsVisibleListView(),
        overrides: _overrides([
          report('draft', now.month, now.year, 'draft', pendingSections: 2),
          report('r1', 2, 2025, 'approved', submittedAt: DateTime(2025, 3, 6)),
          report('r2', 1, 2025, 'approved', submittedAt: DateTime(2025, 2, 6)),
          report('r3', 12, 2024, 'rejected'),
        ]),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Reportes'), findsOneWidget);

      // Por atender: only the draft row.
      expect(find.text('POR ATENDER'), findsOneWidget);
      final attention = find.byKey(const Key('monthly-report-attention-row'));
      expect(attention, findsOneWidget);
      expect(
        find.descendant(
          of: attention,
          matching:
              find.text('${monthlyReportMonthName(now.month)} ${now.year}'),
        ),
        findsOneWidget,
      );
      expect(find.text('Borrador · faltan 2 secciones'), findsOneWidget);

      // History: years with their count; the draft is not repeated there.
      expect(find.text('2025'), findsOneWidget);
      expect(find.text('2024'), findsOneWidget);
      expect(
          find.byKey(const ValueKey('monthly-report-row-draft')), findsNothing);
      expect(find.byType(MonthlyReportHistoryRow), findsNWidgets(3));
      expect(find.text('Enviado el 6 mar'), findsOneWidget);
      expect(find.text('El campo local pidió cambios'), findsOneWidget);

      // Each history row has its status chip.
      expect(find.byType(MonthlyReportStatusChip), findsNWidgets(3));
      expect(find.textContaining('monthly_reports.'), findsNothing);
    },
  );

  testWidgets(
      'a non-draft current report goes to the history, not to attention',
      (tester) async {
    await pumpMonthlyReportsApp(
      tester,
      home: const MonthlyReportsVisibleListView(),
      overrides: _overrides([
        report('gen', now.month, now.year, 'generated'),
      ]),
    );

    expect(find.text('POR ATENDER'), findsNothing);
    expect(find.byType(MonthlyReportHistoryRow), findsOneWidget);
    expect(find.text('Listo para enviar'), findsOneWidget);
  });

  testWidgets('without a report this month the draft row invites to start it',
      (tester) async {
    await pumpMonthlyReportsApp(
      tester,
      home: const MonthlyReportsVisibleListView(),
      overrides: _overrides([report('old', 1, 2020, 'approved')]),
    );

    expect(find.text('POR ATENDER'), findsOneWidget);
    expect(find.textContaining('Sin empezar'), findsOneWidget);
  });

  testWidgets('shows the empty state when there is nothing to show',
      (tester) async {
    await pumpMonthlyReportsApp(
      tester,
      home: const MonthlyReportsVisibleListView(),
      overrides: _overrides(const [], club: null),
    );

    expect(find.text('No hay informes generados'), findsOneWidget);
    expect(find.text('POR ATENDER'), findsNothing);
  });

  testWidgets('shows a skeleton while loading and retry on error',
      (tester) async {
    await pumpMonthlyReportsApp(
      tester,
      home: const MonthlyReportsVisibleListView(),
      overrides: [
        clubContextProvider.overrideWith((ref) async => null),
        monthlyReportsHistoryProvider.overrideWith(
            (ref) => Future<List<VisibleMonthlyReport>>.error('x')),
      ],
    );

    expect(find.text('Reintentar'), findsOneWidget);
  });
}
