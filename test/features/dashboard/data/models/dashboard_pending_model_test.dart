import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/dashboard/data/models/dashboard_pending_model.dart';
import 'package:sacdia_app/features/dashboard/domain/entities/dashboard_pending.dart';

void main() {
  group('DashboardPendingModel.fromJson', () {
    test('parses the full contract payload', () {
      final pending = DashboardPendingModel.fromJson({
        'section_id': 123,
        'generated_at': '2026-11-04T18:00:00.000Z',
        'total': 13,
        'urgent': 1,
        'items': [
          {'type': 'membership_requests', 'count': 3, 'severity': 'warning'},
          {
            'type': 'evidence_folder',
            'count': 2,
            'rejected_count': 1,
            'not_submitted_count': 1,
            'severity': 'urgent',
          },
          {
            'type': 'monthly_report',
            'count': 1,
            'period_month': 10,
            'period_year': 2026,
            'report_status': 'draft',
            'due_date': '2026-11-05',
            'days_left': 1,
            'severity': 'urgent',
          },
          {
            'type': 'investiture_authorizations',
            'count': 7,
            'severity': 'info',
          },
        ],
      });

      expect(pending.sectionId, 123);
      expect(pending.generatedAt, DateTime.utc(2026, 11, 4, 18));
      expect(pending.total, 13);
      expect(pending.urgent, 1);
      expect(pending.items.map((i) => i.type), [
        PendingItemType.membershipRequests,
        PendingItemType.evidenceFolder,
        PendingItemType.monthlyReport,
        PendingItemType.investitureAuthorizations,
      ]);

      final folder = pending.items[1];
      expect(folder.severity, PendingSeverity.urgent);
      expect(folder.rejectedCount, 1);
      expect(folder.notSubmittedCount, 1);

      final report = pending.items[2];
      expect(report.reportStatus, PendingReportStatus.draft);
      expect(report.periodMonth, 10);
      expect(report.periodYear, 2026);
      expect(report.dueDate, DateTime(2026, 11, 5));
      expect(report.daysLeft, 1);
    });

    test('ignores unknown item types and severities', () {
      final pending = DashboardPendingModel.fromJson({
        'total': 5,
        'urgent': 0,
        'items': [
          {'type': 'teleport_requests', 'count': 2, 'severity': 'warning'},
          {'type': 'membership_requests', 'count': 3, 'severity': 'critical'},
          {'type': 'membership_requests', 'count': 3, 'severity': 'warning'},
        ],
      });

      expect(pending.items, hasLength(1));
      expect(pending.items.single.type, PendingItemType.membershipRequests);
      expect(pending.items.single.count, 3);
    });

    test('skips malformed and zero-count rows without failing', () {
      final pending = DashboardPendingModel.fromJson({
        'items': [
          'nope',
          {'type': 'membership_requests', 'severity': 'warning'},
          {'type': 'membership_requests', 'count': 0, 'severity': 'warning'},
          {'type': 'evidence_folder', 'count': '2', 'severity': 'warning'},
        ],
      });

      expect(pending.items, hasLength(1));
      expect(pending.items.single.type, PendingItemType.evidenceFolder);
      expect(pending.items.single.count, 2);
      // Missing totals are derived from the rows that survived.
      expect(pending.total, 2);
      expect(pending.urgent, 0);
    });

    test('empty and missing items produce an empty result', () {
      expect(DashboardPendingModel.fromJson({'items': []}).isEmpty, isTrue);
      expect(DashboardPendingModel.fromJson({}).isEmpty, isTrue);
    });
  });
}
