import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/coordinator/data/models/coordinator_reports_models.dart';
import 'package:sacdia_app/features/coordinator/domain/entities/coordinator_report.dart';
import 'package:sacdia_app/features/coordinator/domain/entities/report_compliance.dart';

/// Shape of GET /reports/compliance → `data` (backend
/// ReportsComplianceService.getCompliance).
Map<String, dynamic> complianceJson() => {
      'as_of': '2026-10-22T12:00:00.000Z',
      'due_day': 5,
      'ecclesiastical_year': {
        'year_id': 7,
        'start_date': '2026-01-01T00:00:00.000Z',
        'end_date': '2026-12-31T00:00:00.000Z',
      },
      'totals': {
        'clubs': 2,
        'monthly': {
          'expected': 18,
          'submitted': 15,
          'pending': 1,
          'overdue': 2,
          'by_period': [
            {
              'year': 2026,
              'month': 8,
              'due_at': '2026-09-05T23:00:00.000Z',
              'expected': 2,
              'submitted': 1,
              'pending': 0,
              'overdue': 1,
            },
            {
              'year': 2026,
              'month': 9,
              'due_at': '2026-10-05T23:00:00.000Z',
              'expected': 2,
              'submitted': 1,
              'pending': 0,
              'overdue': 1,
            },
            {
              'year': 2026,
              'month': 10,
              'due_at': '2026-11-05T23:00:00.000Z',
              'expected': 0,
              'submitted': 0,
              'pending': 0,
              'overdue': 0,
            },
            {
              'year': 2026,
              'month': 11,
              'due_at': '2026-12-05T23:00:00.000Z',
              'expected': 0,
              'submitted': 0,
              'pending': 0,
              'overdue': 0,
            },
          ],
        },
      },
      'total': 2,
      'page': 1,
      'limit': 200,
      'items': [
        {
          'club_id': 10,
          'club_name': 'Club Alfa',
          'local_field_id': 1,
          'local_field_name': 'Campo Norte',
          'sections': [
            {
              'club_section_id': 1,
              'club_type_id': 1,
              'club_type_name': 'Conquistadores',
            },
          ],
          'monthly': {
            'expected': 9,
            'submitted': 9,
            'pending': 0,
            'overdue': 0,
          },
        },
      ],
    };

void main() {
  group('ReportComplianceModel', () {
    test('parses totals, periods and clubs from the backend contract', () {
      final c = ReportComplianceModel.fromJson(complianceJson());

      expect(c.asOf, DateTime.utc(2026, 10, 22, 12));
      expect(c.ecclesiasticalYearId, 7);
      expect(c.clubCount, 2);
      expect(c.monthly.submitted, 15);
      expect(c.monthly.overdue, 2);
      expect(c.monthlyPeriods, hasLength(4));
      expect(c.monthlyPeriods.first.dueAt, DateTime.utc(2026, 9, 5, 23));

      final club = c.clubs.single;
      expect(club.clubId, 10);
      expect(club.clubName, 'Club Alfa');
      expect(club.localFieldName, 'Campo Norte');
      expect(club.sections.single.clubTypeName, 'Conquistadores');
      expect(club.monthly.status, ReportComplianceStatus.submitted);
    });

    test('degrades missing or mistyped fields to zero instead of throwing', () {
      final c = ReportComplianceModel.fromJson({
        'totals': {
          'monthly': {'expected': '3', 'by_period': 'nope'},
        },
        'items': [
          {'club_id': '4', 'club_name': ' Club ', 'sections': null},
        ],
      });
      expect(c.monthly.expected, 3);
      expect(c.monthlyPeriods, isEmpty);
      expect(c.clubs.single.clubId, 4);
      expect(c.clubs.single.clubName, 'Club');
    });

    test(
        'offers only started periods, newest first, defaulting to the newest '
        'one with something expected', () {
      final c = ReportComplianceModel.fromJson(complianceJson());

      final started = c.startedPeriods;
      // November has not started on 2026-10-22.
      expect(started.map((p) => p.index), [10, 9, 8]);
      // October started but nothing is expected yet → September.
      expect(c.defaultPeriod!.index, 9);
    });
  });

  group('ReportCounts.status', () {
    test('worst outcome wins', () {
      expect(const ReportCounts(expected: 2, submitted: 1, overdue: 1).status,
          ReportComplianceStatus.overdue);
      expect(const ReportCounts(expected: 2, submitted: 1, pending: 1).status,
          ReportComplianceStatus.pending);
      expect(const ReportCounts(expected: 2, submitted: 2).status,
          ReportComplianceStatus.submitted);
      expect(ReportCounts.zero.status, ReportComplianceStatus.notDue);
    });
  });

  group('CoordinatorReportModel', () {
    test('monthly admin list item', () {
      final r = CoordinatorReportModel.fromJson({
        'monthly_report_id': 55,
        'club_enrollment_id': 3,
        'month': 9,
        'year': 2026,
        'status': 'submitted',
        'submitted_at': '2026-10-02T10:00:00.000Z',
        'club_name': 'Club Alfa',
        'club_type': 'Conquistadores',
        'club_type_id': 1,
      })!;
      expect(r.id, 55);
      expect(r.clubId, isNull);
      expect(r.clubName, 'Club Alfa');
      expect(r.clubTypeName, 'Conquistadores');
      expect(r.period, 9);
      expect(r.hasPdf, isTrue);
      expect(r.isSubmitted, isTrue);
    });

    test('items without an id are dropped from the page', () {
      final page = CoordinatorReportPage.fromJson({
        'total': 2,
        'items': [
          {'monthly_report_id': 1, 'status': 'generated'},
          {'status': 'generated'},
        ],
      });
      expect(page.items.single.id, 1);
      expect(page.total, 2);
    });
  });

  group('groupReportsByClub', () {
    const clubs = [
      ClubReportCompliance(clubId: 10, clubName: 'Club Alfa'),
      ClubReportCompliance(clubId: 11, clubName: 'Club Beta'),
      ClubReportCompliance(clubId: 12, clubName: 'Club Beta'),
    ];

    test('matches by a unique name; ambiguous names never match', () {
      const reports = [
        CoordinatorReport(
          id: 1,
          status: 'submitted',
          clubName: 'club alfa ',
          clubTypeId: 2,
        ),
        CoordinatorReport(
          id: 2,
          status: 'submitted',
          clubName: 'Club Alfa',
          clubTypeId: 1,
        ),
        CoordinatorReport(
          id: 3,
          status: 'submitted',
          clubName: 'Club Beta',
        ),
      ];

      final grouped = groupReportsByClub(clubs, reports);

      expect(grouped[10]!.map((r) => r.id), [2, 1]);
      expect(grouped[11], isNull);
      expect(grouped[12], isNull);
    });
  });
}
