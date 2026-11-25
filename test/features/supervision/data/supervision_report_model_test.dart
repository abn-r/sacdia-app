import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/supervision/data/models/supervision_report_model.dart';
import 'package:sacdia_app/features/supervision/domain/entities/supervision_report.dart';

Map<String, dynamic> _period(int year, int month, {int expected = 0}) => {
      'year': year,
      'month': month,
      'due_at': '$year-${month.toString().padLeft(2, '0')}-10T00:00:00Z',
      'expected': expected,
      'submitted': 0,
      'pending': 0,
      'overdue': 0,
    };

Map<String, dynamic> _compliance(List<Map<String, dynamic>> byPeriod,
        {String asOf = '2026-03-15T12:00:00Z'}) =>
    {
      'as_of': asOf,
      'totals': {
        'clubs': 3,
        'monthly': {
          'expected': 3,
          'submitted': 1,
          'pending': 1,
          'overdue': 1,
          'by_period': byPeriod,
        },
      },
    };

void main() {
  group('periods', () {
    test('started newest first, future months excluded', () {
      final periods = SupervisionReportModel.parsePeriods(_compliance([
        _period(2026, 1, expected: 2),
        _period(2026, 2),
        _period(2026, 3),
        _period(2026, 4),
        _period(2025, 12, expected: 1),
      ]));
      expect(periods.started.map((p) => p.key), [
        (year: 2026, month: 3),
        (year: 2026, month: 2),
        (year: 2026, month: 1),
        (year: 2025, month: 12),
      ]);
    });

    test('defaultPeriod is the newest with something expected', () {
      final periods = SupervisionReportModel.parsePeriods(_compliance([
        _period(2026, 1, expected: 2),
        _period(2026, 2, expected: 1),
        _period(2026, 3),
      ]));
      expect(periods.defaultPeriod?.key, (year: 2026, month: 2));
    });

    test('defaultPeriod falls back to the newest started', () {
      final periods = SupervisionReportModel.parsePeriods(
          _compliance([_period(2026, 1), _period(2026, 2)]));
      expect(periods.defaultPeriod?.key, (year: 2026, month: 2));
    });

    test('nothing started gives null default', () {
      final periods =
          SupervisionReportModel.parsePeriods(_compliance([_period(2026, 6)]));
      expect(periods.started, isEmpty);
      expect(periods.defaultPeriod, isNull);
    });

    test('bad data does not throw', () {
      expect(SupervisionReportModel.parsePeriods(null).started, isEmpty);
      expect(SupervisionReportModel.parsePeriods('x').started, isEmpty);
      final p = SupervisionReportModel.parsePeriods({
        'as_of': 'nope',
        'totals': 'x',
      });
      expect(p.started, isEmpty);
      final q = SupervisionReportModel.parsePeriods(_compliance([
        {'year': 'x', 'month': 2},
        {'year': 2026, 'month': 13},
        {'year': '2026', 'month': '1', 'expected': '4'},
      ]));
      expect(q.started.single.counts.expected, 4);
    });
  });

  group('compliance page', () {
    test('parses totals, clubs and hasMore', () {
      final page = SupervisionReportModel.parseCompliancePage({
        ..._compliance([]),
        'total': 120,
        'page': 1,
        'limit': 50,
        'items': [
          {
            'club_id': 7,
            'club_name': 'Orion',
            'local_field_id': 1,
            'local_field_name': 'Campo A',
            'sections': [
              {'club_section_id': 1, 'club_type_id': 1, 'club_type_name': 'A'},
              {'club_section_id': 2, 'club_type_id': 1, 'club_type_name': 'A'},
              {'club_section_id': 3, 'club_type_id': 2, 'club_type_name': ' '},
              {'club_section_id': 4, 'club_type_id': 3, 'club_type_name': null},
              {'club_section_id': 5, 'club_type_id': 4, 'club_type_name': 'B'},
            ],
            'monthly': {
              'expected': 1,
              'submitted': 0,
              'pending': 0,
              'overdue': 1,
            },
          },
          {'club_id': 8, 'club_name': 'Sin campo', 'local_field_name': null},
          {'club_name': 'sin id'},
        ],
      }, limit: 50);
      expect(page.totals.expected, 3);
      expect(page.totals.overdue, 1);
      expect(page.clubCount, 3);
      expect(page.total, 120);
      expect(page.hasMore, isTrue);
      expect(page.clubs, hasLength(2));
      final c = page.clubs.first;
      expect(c.clubName, 'Orion');
      expect(c.localFieldName, 'Campo A');
      expect(c.sectionNames, ['A', 'B']);
      expect(c.counts.overdue, 1);
      expect(page.clubs.last.localFieldName, '');
      expect(page.clubs.last.counts, SupervisionReportCounts.zero);
    });

    test('hasMore false on the last page', () {
      final page = SupervisionReportModel.parseCompliancePage(
          {'total': 120, 'page': 3, 'items': []},
          limit: 50);
      expect(page.hasMore, isFalse);
    });

    test('wrong types do not throw', () {
      final page = SupervisionReportModel.parseCompliancePage(
          {'items': 'x', 'totals': [], 'total': 'abc'},
          limit: 50);
      expect(page.clubs, isEmpty);
      expect(page.totals, SupervisionReportCounts.zero);
      expect(
          SupervisionReportModel.parseCompliancePage(null, limit: 50).total, 0);
    });
  });

  group('report list', () {
    test('keeps UUID ids, drops blank, unknown status, hasPdf', () {
      final page = SupervisionReportModel.parseReportPage({
        'total': 60,
        'page': 1,
        'limit': 25,
        'items': [
          {
            'monthly_report_id': '3f2b8c1e-0000-4000-8000-000000000001',
            'status': 'submitted',
            'year': 2026,
            'month': '2',
            'club_name': 'Orion',
            'club_type': 'Conquistadores',
            'local_field': 'Campo A',
            'submitter_name': 'Ana',
            'submitted_at': '2026-03-01T10:00:00Z',
            'member_count': '12',
          },
          {'monthly_report_id': 'b', 'status': 'draft'},
          {'monthly_report_id': 'c', 'status': 'generated'},
          {'monthly_report_id': 'd', 'status': 'weird'},
          {'monthly_report_id': '  ', 'status': 'submitted'},
          {'monthly_report_id': null},
          'junk',
        ],
      }, limit: 25);
      expect(page.items.map((e) => e.id).toList(), [
        '3f2b8c1e-0000-4000-8000-000000000001',
        'b',
        'c',
        'd',
      ]);
      final first = page.items.first;
      expect(first.month, 2);
      expect(first.clubTypeName, 'Conquistadores');
      expect(first.localFieldName, 'Campo A');
      expect(first.submitterName, 'Ana');
      expect(first.submittedAt, isNotNull);
      expect(first.memberCount, 12);
      expect(page.items.map((e) => e.hasPdf), [true, false, true, false]);
      expect(page.items[3].status, SupervisionReportStatus.unknown);
      expect(page.hasMore, isTrue);
      expect(page.total, 60);
    });

    test('nulls and wrong types do not throw', () {
      final report = SupervisionReportModel.tryParseReport({
        'monthly_report_id': 'x',
        'club_name': null,
        'year': 'abc',
        'member_count': {},
        'generated_at': 5,
      })!;
      expect(report.clubName, '');
      expect(report.year, 0);
      expect(report.memberCount, isNull);
      expect(report.generatedAt, isNull);
      expect(
          SupervisionReportModel.parseReportPage(7, limit: 25).items, isEmpty);
    });
  });
}
