import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/dashboard/domain/entities/dashboard_pending.dart';
import 'package:sacdia_app/features/dashboard/presentation/providers/dashboard_pending_provider.dart';
import 'package:sacdia_app/features/monthly_reports/domain/entities/monthly_report.dart';
import 'package:sacdia_app/features/monthly_reports/presentation/providers/monthly_reports_providers.dart';

import '../../../../support/riverpod_test_support.dart';

DashboardPending _pending(List<PendingItem> items) => DashboardPending(
      total: items.length,
      urgent: 0,
      items: items,
    );

void main() {
  group('monthlyReportDueDayProvider', () {
    test('reads the generation day from the dashboard due date', () async {
      final container = createTestContainer(
        overrides: [
          dashboardPendingProvider.overrideWith(
            (ref) async => _pending([
              PendingItem(
                type: PendingItemType.monthlyReport,
                count: 1,
                severity: PendingSeverity.warning,
                dueDate: DateTime.utc(2026, 12, 10, 23),
              ),
            ]),
          ),
        ],
      );
      await container.read(dashboardPendingProvider.future);

      expect(container.read(monthlyReportDueDayProvider), 10);
    });

    test('falls back to the server default when there is no monthly row',
        () async {
      final container = createTestContainer(
        overrides: [
          dashboardPendingProvider.overrideWith((ref) async => _pending([])),
        ],
      );
      await container.read(dashboardPendingProvider.future);

      expect(
        container.read(monthlyReportDueDayProvider),
        kMonthlyReportDefaultDueDay,
      );
      expect(kMonthlyReportDefaultDueDay, 5);
    });

    test('falls back to the default when the dashboard is unavailable',
        () async {
      final container = createTestContainer(
        overrides: [
          dashboardPendingProvider.overrideWith((ref) async => null),
        ],
      );
      await container.read(dashboardPendingProvider.future);

      expect(container.read(monthlyReportDueDayProvider), 5);
    });
  });

  group('monthlyReportPreviousManualDataProvider', () {
    MonthlyReport report(int month, int year, MonthlyReportManualData? data) =>
        MonthlyReport(
          id: '$month-$year',
          enrollmentId: 'e1',
          month: month,
          year: year,
          status: 'approved',
          manualData: data,
        );

    test('returns last month data from the enrollment list', () async {
      final container = createTestContainer(
        overrides: [
          monthlyReportsByEnrollmentProvider.overrideWith(
            (ref, id) async => [
              report(11, 2026, null),
              report(10, 2026,
                  const MonthlyReportManualData(bibleStudiesReceiving: 4)),
            ],
          ),
        ],
      );

      final data = await container.read(
        monthlyReportPreviousManualDataProvider(
            (enrollmentId: 'e1', month: 11, year: 2026)).future,
      );
      expect(data?.bibleStudiesReceiving, 4);
    });

    test('January looks at December of the previous year', () async {
      final container = createTestContainer(
        overrides: [
          monthlyReportsByEnrollmentProvider.overrideWith(
            (ref, id) async => [
              report(12, 2025, const MonthlyReportManualData(soulTarget: 2)),
              report(12, 2026, const MonthlyReportManualData(soulTarget: 9)),
            ],
          ),
        ],
      );

      final data = await container.read(
        monthlyReportPreviousManualDataProvider(
            (enrollmentId: 'e1', month: 1, year: 2026)).future,
      );
      expect(data?.soulTarget, 2);
    });

    test('is null without a previous report or when the list fails', () async {
      final empty = createTestContainer(
        overrides: [
          monthlyReportsByEnrollmentProvider
              .overrideWith((ref, id) async => <MonthlyReport>[]),
        ],
      );
      expect(
        await empty.read(monthlyReportPreviousManualDataProvider(
            (enrollmentId: 'e1', month: 5, year: 2026)).future),
        isNull,
      );

      final failing = createTestContainer(
        overrides: [
          monthlyReportsByEnrollmentProvider.overrideWith(
              (ref, id) => Future<List<MonthlyReport>>.error('offline')),
        ],
      );
      expect(
        await failing.read(monthlyReportPreviousManualDataProvider(
            (enrollmentId: 'e1', month: 5, year: 2026)).future),
        isNull,
      );
    });
  });
}
