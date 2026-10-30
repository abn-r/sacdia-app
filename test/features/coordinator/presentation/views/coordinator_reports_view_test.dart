/// Tests for CoordinatorReportsView (read-only club reports).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/widgets/sac_badge.dart';
import 'package:sacdia_app/core/widgets/sac_empty_state.dart';
import 'package:sacdia_app/core/widgets/sac_error_state.dart';
import 'package:sacdia_app/core/widgets/sac_filter_chip.dart';
import 'package:sacdia_app/core/widgets/sac_stat_tile.dart';
import 'package:sacdia_app/features/coordinator/domain/entities/coordinator_report.dart';
import 'package:sacdia_app/features/coordinator/domain/entities/report_compliance.dart';
import 'package:sacdia_app/features/coordinator/presentation/providers/coordinator_providers.dart';
import 'package:sacdia_app/features/coordinator/presentation/providers/coordinator_reports_providers.dart';
import 'package:sacdia_app/features/coordinator/presentation/views/coordinator_reports_view.dart';

import '../../coordinator_test_harness.dart';
import '../../../../support/riverpod_test_support.dart';

ReportCompliancePeriod _month(int month, ReportCounts counts) =>
    ReportCompliancePeriod(
      year: 2026,
      index: month,
      counts: counts,
      dueAt: DateTime.utc(2026, month + 1, 5, 23),
    );

final _year = ReportCompliance(
  asOf: DateTime.utc(2026, 10, 22),
  ecclesiasticalYearId: 7,
  clubCount: 2,
  monthly: const ReportCounts(expected: 6, submitted: 4, overdue: 2),
  quarterly: const ReportCounts(expected: 2, submitted: 1, pending: 1),
  annual: ReportCounts.zero,
  monthlyPeriods: [
    _month(8, const ReportCounts(expected: 3, submitted: 2, overdue: 1)),
    _month(9, const ReportCounts(expected: 3, submitted: 2, overdue: 1)),
    _month(10, ReportCounts.zero),
    _month(11, ReportCounts.zero),
  ],
  quarterlyPeriods: [
    ReportCompliancePeriod(
      year: 2026,
      index: 3,
      counts: const ReportCounts(expected: 2, submitted: 1, pending: 1),
      dueAt: DateTime.utc(2026, 10, 5, 23),
    ),
  ],
  clubs: const [
    ClubReportCompliance(clubId: 10, clubName: 'Club Alfa'),
    ClubReportCompliance(clubId: 11, clubName: 'Club Beta'),
  ],
);

/// September monthly compliance (and Q3 for the quarterly kind).
ReportCompliance _period(ComplianceQuery query) => ReportCompliance(
      asOf: DateTime.utc(2026, 10, 22),
      ecclesiasticalYearId: 7,
      clubCount: 2,
      monthly: const ReportCounts(expected: 3, submitted: 2, overdue: 1),
      quarterly: const ReportCounts(expected: 2, submitted: 1, pending: 1),
      annual: ReportCounts.zero,
      clubs: const [
        ClubReportCompliance(
          clubId: 10,
          clubName: 'Club Alfa',
          localFieldName: 'Campo Norte',
          monthly: ReportCounts(expected: 2, submitted: 2),
          quarterly: ReportCounts(expected: 1, submitted: 1),
        ),
        ClubReportCompliance(
          clubId: 11,
          clubName: 'Club Beta',
          monthly: ReportCounts(expected: 1, overdue: 1),
          quarterly: ReportCounts(expected: 1, pending: 1),
        ),
      ],
    );

const _monthlyReports = [
  CoordinatorReport(
    id: 55,
    kind: CoordinatorReportKind.monthly,
    status: 'submitted',
    clubName: 'Club Alfa',
    clubTypeId: 1,
    clubTypeName: 'Conquistadores',
  ),
  CoordinatorReport(
    id: 56,
    kind: CoordinatorReportKind.monthly,
    status: 'draft',
    clubName: 'Club Alfa',
    clubTypeId: 2,
    clubTypeName: 'Aventureros',
  ),
];

const _quarterlyReports = [
  CoordinatorReport(
    id: 8,
    kind: CoordinatorReportKind.quarterly,
    status: 'finalized',
    clubId: 10,
    clubName: 'Club Alfa',
  ),
];

class _Calls {
  final compliance = <ComplianceQuery>[];
  final lists = <ReportListQuery>[];
  final pdfs = <ReportPdfKey>[];
}

Future<_Calls> _pump(
  WidgetTester tester, {
  Future<ReportCompliance> Function()? year,
}) async {
  useTallSurface(tester);
  final calls = _Calls();

  await tester.pumpWidget(
    testProviderScope(
      overrides: [
        reportComplianceProvider.overrideWith((ref, query) async {
          calls.compliance.add(query);
          if (query == kWholeYearCompliance) {
            return year != null ? year() : _year;
          }
          return _period(query);
        }),
        coordinatorReportListProvider.overrideWith((ref, query) async {
          calls.lists.add(query);
          return switch (query.kind) {
            CoordinatorReportKind.monthly => _monthlyReports,
            CoordinatorReportKind.quarterly => _quarterlyReports,
            CoordinatorReportKind.annual => const <CoordinatorReport>[],
          };
        }),
        coordinatorReportPdfProvider.overrideWith((ref, key) async {
          calls.pdfs.add(key);
          throw const CoordinatorLoadException('boom');
        }),
      ],
      child: localized(
        (context) => localizedApp(context, const CoordinatorReportsView()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return calls;
}

void main() {
  setUpAll(initCoordinatorTestLocalization);

  testWidgets('defaults to the newest monthly period with reports expected',
      (tester) async {
    final calls = await _pump(tester);

    expect(find.text('Informes'), findsOneWidget);
    expect(find.widgetWithText(SacFilterChip, 'Mensual'), findsOneWidget);
    expect(find.widgetWithText(SacFilterChip, 'Trimestral'), findsOneWidget);
    expect(find.widgetWithText(SacFilterChip, 'Anual'), findsOneWidget);

    // Started months only (Oct, Sep, Aug); November is in the future.
    final periodChips = tester
        .widgetList<SacFilterChip>(find.byType(SacFilterChip))
        .where((chip) => chip.variant == SacFilterChipVariant.quiet)
        .toList();
    expect(periodChips, hasLength(3));
    // October has nothing expected yet, so September is selected.
    expect(periodChips.map((c) => c.selected), [false, true, false]);

    expect(calls.compliance, contains((year: 2026, month: 9, quarter: null)));
    expect(
      calls.lists,
      contains((
        kind: CoordinatorReportKind.monthly,
        year: 2026,
        period: 9,
        ecclesiasticalYearId: null,
      )),
    );
  });

  testWidgets('shows the period totals and one status card per club',
      (tester) async {
    await _pump(tester);

    expect(find.byType(SacStatTile), findsNWidgets(3));
    expect(find.text('Enviados'), findsOneWidget);
    expect(find.text('Vencidos'), findsOneWidget);

    expect(find.text('Club Alfa'), findsOneWidget);
    expect(find.text('Campo Norte'), findsOneWidget);
    expect(find.text('2 de 2 enviados'), findsOneWidget);
    expect(find.widgetWithText(SacBadge, 'Enviado'), findsOneWidget);
    expect(find.widgetWithText(SacBadge, 'Vencido'), findsOneWidget);

    // Only the generated/submitted monthly report offers a PDF.
    expect(find.text('Ver PDF · Conquistadores'), findsOneWidget);
    expect(find.text('Ver PDF · Aventureros'), findsNothing);
    expect(find.text('Sin PDF disponible todavía'), findsOneWidget);
  });

  testWidgets('offers no finalize, regenerate or submit action',
      (tester) async {
    await _pump(tester);

    for (final text in ['Finalizar', 'Regenerar', 'Enviar', 'Generar']) {
      expect(find.text(text), findsNothing, reason: text);
    }
  });

  testWidgets('switching to quarterly reloads Q3 and shows its PDF',
      (tester) async {
    final calls = await _pump(tester);

    await tester.tap(find.widgetWithText(SacFilterChip, 'Trimestral'));
    await tester.pumpAndSettle();

    expect(calls.compliance, contains((year: 2026, month: null, quarter: 3)));
    expect(find.text('T3 2026'), findsOneWidget);
    expect(find.widgetWithText(SacBadge, 'Pendiente'), findsOneWidget);
    expect(find.text('Ver PDF'), findsOneWidget);
  });

  testWidgets('annual reports list by ecclesiastical year without periods',
      (tester) async {
    final calls = await _pump(tester);

    await tester.tap(find.widgetWithText(SacFilterChip, 'Anual'));
    await tester.pumpAndSettle();

    expect(
      calls.lists,
      contains((
        kind: CoordinatorReportKind.annual,
        year: null,
        period: null,
        ecclesiasticalYearId: 7,
      )),
    );
    expect(
      tester
          .widgetList<SacFilterChip>(find.byType(SacFilterChip))
          .where((chip) => chip.variant == SacFilterChipVariant.quiet),
      isEmpty,
    );
    // Nothing expected yet for the year.
    expect(find.widgetWithText(SacBadge, 'En curso'), findsNWidgets(2));
  });

  testWidgets('opening a PDF downloads that report and reports failures',
      (tester) async {
    final calls = await _pump(tester);

    await tester.tap(find.text('Ver PDF · Conquistadores'));
    await tester.pumpAndSettle();

    expect(calls.pdfs, [(kind: CoordinatorReportKind.monthly, id: 55)]);
    expect(
      find.text('No se pudo abrir el PDF. Inténtalo de nuevo.'),
      findsOneWidget,
    );
  });

  testWidgets('a 403 renders the access-restricted state', (tester) async {
    await _pump(
      tester,
      year: () async =>
          throw const CoordinatorLoadException('403', isForbidden: true),
    );

    final state = tester.widget<SacErrorState>(find.byType(SacErrorState));
    expect(state.icon, HugeIcons.strokeRoundedLockKey);
    expect(find.byType(SacFilterChip), findsNothing);
  });

  testWidgets('no clubs in scope renders the empty state', (tester) async {
    await _pump(
      tester,
      year: () async => ReportCompliance(
        asOf: DateTime.utc(2026, 10, 22),
        ecclesiasticalYearId: 7,
        clubCount: 0,
        monthly: ReportCounts.zero,
        quarterly: ReportCounts.zero,
        annual: ReportCounts.zero,
      ),
    );

    expect(find.byType(SacEmptyState), findsOneWidget);
    expect(find.text('Sin clubes asignados'), findsOneWidget);
  });
}
