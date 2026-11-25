import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/supervision/data/models/supervision_pending_counts_model.dart';
import 'package:sacdia_app/features/supervision/domain/entities/supervision_pending_counts.dart';

void main() {
  group('SupervisionPendingCountsModel.fromJson', () {
    test('parses a full payload', () {
      final m = SupervisionPendingCountsModel.fromJson({
        'territory_level': 'union',
        'counts': {
          'club_enrollments': 3,
          'annual_folders': 0,
          'union_camporee_registrations': 4,
          'transfers': 2,
          'role_assignments': 1,
        },
      });
      expect(m.territoryLevel, 'union');
      expect(m.clubEnrollments, 3);
      expect(m.annualFolders, 0);
      expect(m.unionCamporeeRegistrations, 4);
      expect(m.transfers, 2);
      expect(m.roleAssignments, 1);
      expect(m.total, 10);
    });

    test('null counts stay null, zero stays zero', () {
      final m = SupervisionPendingCountsModel.fromJson({
        'territory_level': 'union',
        'counts': {
          'club_enrollments': 3,
          'annual_folders': 0,
          'union_camporee_registrations': null,
          'transfers': 2,
          'role_assignments': 1,
        },
      });
      expect(m.unionCamporeeRegistrations, isNull);
      expect(m.annualFolders, 0);
    });

    test('missing counts object yields null counts', () {
      final m = SupervisionPendingCountsModel.fromJson(
          {'territory_level': 'division'});
      expect(m.territoryLevel, 'division');
      expect(m.clubEnrollments, isNull);
      expect(m.requests, isNull);
      expect(m.total, 0);
    });

    test('counts of the wrong type yield null counts', () {
      expect(
        SupervisionPendingCountsModel.fromJson(
            {'territory_level': 'all', 'counts': 'x'}).clubEnrollments,
        isNull,
      );
      final m = SupervisionPendingCountsModel.fromJson({
        'territory_level': 5,
        'counts': {
          'club_enrollments': '3',
          'annual_folders': 1.5,
          'transfers': true,
          'role_assignments': <int>[],
        },
      });
      expect(m.territoryLevel, 'unconfigured');
      expect(m.clubEnrollments, isNull);
      expect(m.annualFolders, isNull);
      expect(m.transfers, isNull);
      expect(m.roleAssignments, isNull);
    });
  });

  group('SupervisionPendingCounts.requests', () {
    test('null only when both are null', () {
      expect(
          const SupervisionPendingCounts(territoryLevel: 'x').requests, isNull);
    });

    test('one null returns the other', () {
      expect(
        const SupervisionPendingCounts(territoryLevel: 'x', transfers: 2)
            .requests,
        2,
      );
      expect(
        const SupervisionPendingCounts(territoryLevel: 'x', roleAssignments: 5)
            .requests,
        5,
      );
    });

    test('both sum', () {
      expect(
        const SupervisionPendingCounts(
                territoryLevel: 'x', transfers: 2, roleAssignments: 5)
            .requests,
        7,
      );
    });
  });
}
