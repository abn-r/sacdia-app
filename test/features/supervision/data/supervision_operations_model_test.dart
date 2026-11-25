import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/supervision/data/models/supervision_operations_model.dart';
import 'package:sacdia_app/features/supervision/domain/entities/supervision_operations.dart';

Map<String, dynamic> _metrics({
  int total = 10,
  int missing = 0,
  int nonOp = 0,
  Map<String, dynamic>? queues,
  Object? attribution = 'current_affiliation',
}) =>
    {
      'administrative_clubs': {'total': total, 'active': 8, 'inactive': 2},
      'operations': {
        'operational_clubs': 7,
        'non_operational_clubs': nonOp,
        'operational_sections': 12,
        'operational_rate_pct': 87.5,
      },
      'people': {
        'institutionally_active': 120,
        'platform_accounts': {'active': 90, 'inactive': 30},
      },
      'classes': {
        'total_enrollments': 55,
        'distinct_people': 50,
        'by_class': [
          {
            'class_id': 2,
            'class_name': 'Amigo',
            'club_type_id': 1,
            'club_type_name': 'Aventureros',
            'display_order': 2,
            'enrollment_count': 30,
          },
          {
            'class_id': 1,
            'class_name': 'Abeja',
            'club_type_id': 1,
            'club_type_name': 'Aventureros',
            'display_order': 1,
            'enrollment_count': 25,
          },
        ],
      },
      'monthly_reports': {
        'expected_sections': 20,
        'submitted_sections': 10,
        'draft_sections': 3,
        'generated_sections': 2,
        'missing_sections': missing,
        'coverage_pct': 50,
      },
      'honors': {
        'in_progress': 4,
        'pending_review': null,
        'approved': 9,
        'attribution': attribution,
      },
      'activities': {
        'registered': 14,
        'joint_registered': 3,
        'distinct_participating_sections': 6,
      },
      'queues': queues ??
          {
            'role_assignments_pending': 1,
            'transfers_pending': 2,
            'class_validations_pending': 3,
            'honors_review_pending': null,
            'annual_folders_pending_union': 4,
          },
    };

Map<String, dynamic> _child(
  int id,
  String name, {
  int missing = 0,
  int nonOp = 0,
  Map<String, dynamic>? queues,
  Object? level = 'union',
}) =>
    {
      'id': id,
      'name': name,
      'level': level,
      ..._metrics(missing: missing, nonOp: nonOp, queues: queues),
    };

void main() {
  group('parseDashboard', () {
    test('parses a full payload', () {
      final d = SupervisionOperationsModel.parseDashboard({
        'meta': {
          'computed_at': '2026-11-20T15:30:00.000Z',
          'scope': {
            'level': 'union',
            'id': 4,
            'name': 'Union Norte',
            'path': [
              {'level': 'division', 'id': 1, 'name': 'Division A'},
              {'level': 'union', 'id': 4, 'name': 'Union Norte'},
            ],
          },
          'period': {
            'ecclesiastical_year': {
              'id': 9,
              'start_date': '2026-01-01',
              'end_date': '2026-12-31',
              'active': true,
            },
            'reporting_month': {'year': 2026, 'month': 10},
          },
        },
        'summary': _metrics(missing: 2),
        'children': [_child(7, 'Campo B')],
        'data_quality': [
          {'x': 1}
        ],
      });

      expect(d.scope.level, SupervisionTerritoryLevel.union);
      expect(d.scope.id, 4);
      expect(d.scope.path.map((e) => e.level), [
        SupervisionTerritoryLevel.division,
        SupervisionTerritoryLevel.union,
      ]);
      expect(d.period.yearId, 9);
      expect(d.period.yearStart, DateTime(2026, 1, 1));
      expect(d.period.yearEnd, DateTime(2026, 12, 31));
      expect(d.period.hasReportingMonth, isTrue);
      expect(d.period.reportMonth, 10);
      expect(d.computedAt, isNotNull);

      final m = d.summary;
      expect(m.clubsTotal, 10);
      expect(m.clubsInactive, 2);
      expect(m.operationalRatePct, 87.5);
      expect(m.accountsActive, 90);
      expect(m.classes.map((c) => c.classId), [2, 1]); // server order
      expect(m.classes.first.className, 'Amigo');
      expect(m.reportsCoveragePct, 50.0);
      expect(m.honorsInProgress, 4);
      expect(m.honorsPendingReview, isNull);
      expect(m.honorsAvailable, isTrue);
      expect(m.activitiesJoint, 3);
      expect(m.pendingTotal, 10);
      expect(m.hasGap, isTrue);
      expect(d.children.single.id, 7);
      expect(d.children.single.metrics.clubsTotal, 10);
    });

    test('zero / empty payload yields empty metrics', () {
      final d = SupervisionOperationsModel.parseDashboard({
        'meta': {
          'scope': {'level': 'all', 'id': null, 'name': 'Todos', 'path': []},
          'period': {
            'ecclesiastical_year': {'id': 1},
            'reporting_month': null,
          },
        },
        'summary': {},
        'children': [],
      });
      expect(d.summary, SupervisionOperationsMetrics.empty);
      expect(d.children, isEmpty);
      expect(d.scope.level, SupervisionTerritoryLevel.all);
      expect(d.scope.id, isNull);
      expect(d.period.hasReportingMonth, isFalse);
      expect(d.computedAt, isNull);
      expect(SupervisionOperationsMetrics.empty.hasGap, isFalse);
      expect(SupervisionOperationsMetrics.empty.honorsAvailable, isFalse);
    });

    test('nulls and wrong types never throw', () {
      for (final raw in <Object?>[
        null,
        'x',
        42,
        <Object?>[],
        {'meta': 'x', 'summary': [], 'children': 'no'},
        {
          'summary': {
            'administrative_clubs': {'total': '12', 'active': 'abc'},
            'operations': {'operational_rate_pct': '66.5'},
            'classes': {'by_class': 'nope'},
            'queues': 5,
          },
          'children': [
            null,
            3,
            {'name': 'no id'}
          ],
        },
      ]) {
        final d = SupervisionOperationsModel.parseDashboard(raw);
        expect(d.children, isEmpty);
      }
      final d = SupervisionOperationsModel.parseDashboard({
        'summary': {
          'administrative_clubs': {'total': '12', 'active': 'abc'},
          'operations': {'operational_rate_pct': '66.5'},
        },
      });
      expect(d.summary.clubsTotal, 12);
      expect(d.summary.clubsActive, 0);
      expect(d.summary.operationalRatePct, 66.5);
    });

    test('unknown levels map to unknown', () {
      final d = SupervisionOperationsModel.parseDashboard({
        'meta': {
          'scope': {
            'level': 'galaxy',
            'path': [
              {'level': 7, 'id': 1, 'name': 'X'}
            ],
          },
        },
        'children': [_child(1, 'A', level: 'planet')],
      });
      expect(d.scope.level, SupervisionTerritoryLevel.unknown);
      expect(d.scope.path.single.level, SupervisionTerritoryLevel.unknown);
      expect(d.children.single.level, SupervisionTerritoryLevel.unknown);
    });

    test('honorsAvailable is false when attribution is unavailable', () {
      final m = SupervisionOperationsModel.parseMetrics(
          _metrics(attribution: 'unavailable'));
      expect(m.honorsAvailable, isFalse);
    });

    test('pendingTotal counts null queues as zero', () {
      final m = SupervisionOperationsModel.parseMetrics(_metrics(queues: {
        'role_assignments_pending': 5,
        'honors_review_pending': null,
      }));
      expect(m.pendingTotal, 5);
    });

    test('children: gaps first, then missing, non-operational, pending, name',
        () {
      const none = {
        'role_assignments_pending': 0,
        'transfers_pending': 0,
        'class_validations_pending': 0,
        'honors_review_pending': 0,
        'annual_folders_pending_union': 0,
      };
      final d = SupervisionOperationsModel.parseDashboard({
        'children': [
          _child(1, 'zeta ok', queues: none),
          _child(2, 'alpha ok', queues: none),
          _child(3, 'gap nonop 1', nonOp: 1, queues: none),
          _child(4, 'gap missing 1', missing: 1, queues: none),
          _child(5, 'gap missing 3', missing: 3, queues: none),
          _child(6, 'gap nonop 2', nonOp: 2, queues: none),
          _child(7, 'Beta ok pending',
              queues: {...none, 'transfers_pending': 9}),
        ],
      });
      expect(d.children.map((c) => c.id), [5, 4, 6, 3, 7, 2, 1]);
    });
  });
}
