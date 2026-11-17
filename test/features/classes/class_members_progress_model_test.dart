import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/classes/data/models/class_members_progress_result_model.dart';
import 'package:sacdia_app/features/classes/data/models/progress_scope_result_model.dart';
import 'package:sacdia_app/features/classes/domain/entities/class_progress_summary.dart';

void main() {
  group('ClassMemberProgressModel.fromJson — cross_type_enrollment', () {
    Map<String, dynamic> baseJson({Object? crossTypeEnrollment}) => {
          'user_id': 'user-abc',
          'name': 'Ana Torres',
          'enrollment_id': 42,
          'class_id': 7,
          'ecclesiastical_year_id': 2026,
          'investiture_status': 'NONE',
          'completed_sections': 3,
          'total_sections': 8,
          'overall_progress': 37,
          if (crossTypeEnrollment != null)
            'cross_type_enrollment': crossTypeEnrollment,
        };

    test('defaults to false when field is absent', () {
      final model = ClassMemberProgressModel.fromJson(baseJson());
      expect(model.crossTypeEnrollment, isFalse);
    });

    test('parses true when field is true', () {
      final model = ClassMemberProgressModel.fromJson(
          baseJson(crossTypeEnrollment: true));
      expect(model.crossTypeEnrollment, isTrue);
    });

    test('stays false when field is explicitly false', () {
      final model = ClassMemberProgressModel.fromJson(
          baseJson(crossTypeEnrollment: false));
      expect(model.crossTypeEnrollment, isFalse);
    });

    test('stays false when field is a non-true value (e.g. null)', () {
      final model = ClassMemberProgressModel.fromJson(
          baseJson(crossTypeEnrollment: null));
      expect(model.crossTypeEnrollment, isFalse);
    });

    test('toJson round-trips crossTypeEnrollment', () {
      final model = ClassMemberProgressModel.fromJson(
          baseJson(crossTypeEnrollment: true));
      expect(model.toJson()['cross_type_enrollment'], isTrue);
    });

    test('toEntity propagates crossTypeEnrollment', () {
      final model = ClassMemberProgressModel.fromJson(
          baseJson(crossTypeEnrollment: true));
      expect(model.toEntity().crossTypeEnrollment, isTrue);
    });

    test('props includes crossTypeEnrollment for equality', () {
      final a = ClassMemberProgressModel.fromJson(
          baseJson(crossTypeEnrollment: true));
      final b = ClassMemberProgressModel.fromJson(
          baseJson(crossTypeEnrollment: false));
      expect(a, isNot(equals(b)));
    });
  });

  group('status_counts, summary and responsibles', () {
    Map<String, dynamic> member(Map<String, dynamic> extra) => {
          'user_id': 'u1',
          'name': 'Ana',
          'enrollment_id': 1,
          'class_id': 7,
          'ecclesiastical_year_id': 12,
          'investiture_status': 'NONE',
          'completed_sections': 3,
          'total_sections': 8,
          'overall_progress': 37,
          ...extra,
        };

    test('member counts default to zero on an older server', () {
      final m = ClassMemberProgressModel.fromJson(member({}));
      expect(m.statusCounts, RequirementStatusCounts.zero);
      expect(m.toEntity().isBehind, isTrue);
      expect(m.toEntity().hasRejected, isFalse);
    });

    test('member counts are parsed and flag rejected', () {
      final m = ClassMemberProgressModel.fromJson(member({
        'status_counts': {
          'validated': 3,
          'submitted': 1,
          'rejected': 2,
          'pending': '5',
        },
      }));
      expect(m.statusCounts.validated, 3);
      expect(m.statusCounts.pending, 5);
      expect(m.statusCounts.total, 11);
      expect(m.toEntity().hasRejected, isTrue);
      expect(m.toJson()['status_counts'], containsPair('rejected', 2));
    });

    test('a malformed status_counts is ignored', () {
      final m = ClassMemberProgressModel.fromJson(
        member({'status_counts': 'oops'}),
      );
      expect(m.statusCounts, RequirementStatusCounts.zero);
    });

    test('result parses summary, counselor and assistant', () {
      final r = ClassMembersProgressResultModel.fromJson({
        'club_section_id': 3,
        'club_type_id': 2,
        'class_id': 7,
        'ecclesiastical_year_id': 12,
        'access_level': 'section',
        'members': [member({})],
        'summary': {
          'avg_progress': 140,
          'status_counts': {'validated': 4, 'rejected': 1},
        },
        'counselor': {'user_id': 'c1', 'name': 'Laura'},
        'assistant': null,
      }).toEntity();
      expect(r.summary.avgProgress, 100);
      expect(r.summary.statusCounts.validated, 4);
      expect(r.summary.statusCounts.submitted, 0);
      expect(r.counselor, const ClassResponsible(userId: 'c1', name: 'Laura'));
      expect(r.assistant, isNull);
    });

    test('result without the new fields falls back to empty', () {
      final r = ClassMembersProgressResultModel.fromJson({
        'members': [member({})],
      }).toEntity();
      expect(r.summary, const ClassProgressSummary());
      expect(r.counselor, isNull);
    });
  });

  group('progress scope', () {
    Map<String, dynamic> cls(int id, int members, int avg,
            {Map<String, dynamic>? extra}) =>
        {
          'class_id': id,
          'name': 'C$id',
          'club_type_id': 2,
          'access_level': 'section',
          'members_count': members,
          'avg_progress': avg,
          'status_counts': {
            'validated': 1,
            'submitted': 2,
            'rejected': 3,
            'pending': 4,
          },
          ...?extra,
        };

    test('class parses the new fields', () {
      final c = ProgressScopeClassModel.fromJson(cls(1, 9, 62, extra: {
        'counselor': {'user_id': 'c', 'name': 'Laura'},
        'assistant': {'user_id': 'a', 'name': 'Diego'},
      })).toEntity();
      expect(c.membersCount, 9);
      expect(c.avgProgress, 62);
      expect(c.statusCounts.rejected, 3);
      expect(c.counselor?.name, 'Laura');
      expect(c.assistant?.userId, 'a');
    });

    test('class without the new fields has zeros and no people', () {
      final c = ProgressScopeClassModel.fromJson({
        'class_id': 1,
        'name': 'Amigo',
        'club_type_id': 2,
        'access_level': 'section',
      }).toEntity();
      expect(c.membersCount, 0);
      expect(c.avgProgress, 0);
      expect(c.statusCounts.total, 0);
      expect(c.counselor, isNull);
    });

    test('a counselor without user_id counts as nobody', () {
      final c = ProgressScopeClassModel.fromJson(cls(1, 1, 1, extra: {
        'counselor': {'name': 'Sin id'},
      }));
      expect(c.counselor, isNull);
    });

    test('result weights the average by members and sums the counts', () {
      final r = ProgressScopeResultModel.fromJson({
        'club_section_id': 3,
        'club_type_id': 2,
        'ecclesiastical_year_id': 12,
        'access_level': 'section',
        'classes': [cls(1, 9, 60), cls(2, 1, 100)],
      }).toEntity();
      expect(r.totalMembers, 10);
      expect(r.weightedAvgProgress, 64);
      expect(r.totalStatusCounts.rejected, 6);
    });

    test('empty scope averages 0', () {
      final r = ProgressScopeResultModel.fromJson({'classes': []}).toEntity();
      expect(r.weightedAvgProgress, 0);
    });

    test('toJson round-trips the new fields', () {
      final m = ProgressScopeClassModel.fromJson(cls(1, 9, 62));
      expect(ProgressScopeClassModel.fromJson(m.toJson()), m);
    });
  });
}
