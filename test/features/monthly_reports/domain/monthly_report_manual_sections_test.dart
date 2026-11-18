import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/monthly_reports/domain/entities/monthly_report.dart';

MonthlyReport _report(MonthlyReportManualData? manual) => MonthlyReport(
      id: 'r',
      enrollmentId: 'e',
      month: 11,
      year: 2026,
      status: 'draft',
      manualData: manual,
    );

void main() {
  group('manual sections', () {
    test('a report without manual data has every section pending', () {
      expect(
        _report(null).pendingManualSections,
        MonthlyReportManualSection.values,
      );
    });

    test('defaults (zeros, false, no text) do not count as filled', () {
      const data = MonthlyReportManualData(
        planningMeetings: 0,
        hasWeeklyBibleInstruction: false,
      );
      for (final section in MonthlyReportManualSection.values) {
        expect(data.isSectionFilled(section), isFalse, reason: '$section');
      }
    });

    test('each section is filled by its own fields only', () {
      expect(
        const MonthlyReportManualData(planningMeetings: 1)
            .isSectionFilled(MonthlyReportManualSection.meetings),
        isTrue,
      );
      expect(
        const MonthlyReportManualData(literatureDistributed: true)
            .isSectionFilled(MonthlyReportManualSection.mission),
        isTrue,
      );
      expect(
        const MonthlyReportManualData(communityServiceDescription: ' x ')
            .isSectionFilled(MonthlyReportManualSection.service),
        isTrue,
      );
      expect(
        const MonthlyReportManualData(certificatesDelivered: true)
            .isSectionFilled(MonthlyReportManualSection.materials),
        isTrue,
      );
      expect(
        const MonthlyReportManualData(planningMeetings: 1)
            .isSectionFilled(MonthlyReportManualSection.mission),
        isFalse,
      );
    });

    test('pending sections keep the form order', () {
      final report = _report(const MonthlyReportManualData(
        planningMeetings: 2,
        certificatesDelivered: true,
      ));
      expect(report.pendingManualSections, [
        MonthlyReportManualSection.mission,
        MonthlyReportManualSection.service,
      ]);
    });

    test('the history row carries how many sections are missing', () {
      final visible = VisibleMonthlyReport.fromReport(
        _report(const MonthlyReportManualData(planningMeetings: 2)),
      );
      expect(visible.pendingSections, 3);
    });
  });
}
