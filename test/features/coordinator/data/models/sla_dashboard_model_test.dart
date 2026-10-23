import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/coordinator/data/models/sla_dashboard_model.dart';

void main() {
  group('SlaDashboardModel.fromJson', () {
    test('maps backend SlaDashboardDto (validation.total_pending → evidence)',
        () {
      final sla = SlaDashboardModel.fromJson({
        'investiture': {
          'total_pending': 3,
          'in_review': 1,
          'overdue': 1,
          'pipeline': [
            {
              'status': 'SUBMITTED_FOR_VALIDATION',
              'label': 'Enviado para validación',
              'count': 3,
            },
          ],
        },
        'validation': {
          'class_sections_pending': 4,
          'honors_pending': 2,
          'total_pending': 6,
        },
        'camporee': {
          'clubs_pending': 1,
          'members_pending': 2,
          'payments_pending': 0,
        },
        'timing': {'avg_days_total': 12.5},
        'throughput': [
          {'week': '2026-W40', 'approved': 5, 'rejected': 1},
        ],
        'approval_rate': {'resolved': 6, 'approved': 5, 'rate': 0.83},
        'computed_at': '2026-10-14T12:00:00.000Z',
        'cached': false,
      }).toEntity();

      expect(sla.evidence.pending, 6);
      expect(sla.investiture.pending, 3);
      expect(sla.investiture.overdue, 1);
      expect(sla.investiture.avgDays, 12.5);
      expect(sla.camporee.pending, 3);
      expect(sla.totalOverdue, 1);
      expect(sla.pipeline.single.stage, 'Enviado para validación');
      expect(sla.pipeline.single.count, 3);
      expect(sla.throughput.single.approved, 5);
    });

    test('keeps legacy per-process shape working', () {
      final sla = SlaDashboardModel.fromJson({
        'investiture': {'pending': 2, 'avgDays': 4, 'overdue': 0},
        'evidence': {'pending': 5, 'avg_days': 1.5, 'overdue': 2},
        'camporee': {'pending': 1, 'overdue': 0},
      }).toEntity();

      expect(sla.evidence.pending, 5);
      expect(sla.evidence.overdue, 2);
      expect(sla.investiture.pending, 2);
      expect(sla.camporee.pending, 1);
      expect(sla.evidence.overdueThresholdDays, isNull);
    });

    test('reads the evidence SLA block, including overdue_threshold_days', () {
      final sla = SlaDashboardModel.fromJson({
        'validation': {'total_pending': 6},
        'evidence': {
          'pending': 6,
          'overdue': 3,
          'avg_days': 92.3,
          'overdue_threshold_days': 10,
        },
      }).toEntity();

      expect(sla.evidence.pending, 6);
      expect(sla.evidence.overdue, 3);
      expect(sla.evidence.avgDays, 92.3);
      expect(sla.evidence.overdueThresholdDays, 10);
    });

    test('a null avg_days and a missing or invalid threshold fall back', () {
      final sla = SlaDashboardModel.fromJson({
        'evidence': {
          'pending': 0,
          'overdue': 0,
          'avg_days': null,
          'overdue_threshold_days': 0,
        },
      }).toEntity();

      expect(sla.evidence.avgDays, 0.0);
      expect(sla.evidence.overdueThresholdDays, isNull);
    });
  });
}
